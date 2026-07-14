import AILimitBarCore
import Foundation
import WebKit

@MainActor
final class OllamaWebPageClientController: NSObject, OllamaWebPageClient, @unchecked Sendable {
    static let settingsURL = URL(string: "https://ollama.com/settings")!
    private var sessions: [String: OllamaWebPageSession] = [:]

    func fetchUsage(account: ProviderAccount) async throws -> OllamaUsagePagePayload {
        guard account.webDataStoreID != nil else {
            throw ProviderAdapterError(
                providerID: "ollama-cloud",
                message: "Ollama session is not connected.",
                recoverySuggestion: "Choose Connect Ollama and sign in through AI Limitbar."
            )
        }
        return try await session(for: account).loadUsage(interactive: false)
    }

    func connect(account: ProviderAccount) async throws -> OllamaUsagePagePayload {
        guard account.webDataStoreID != nil else {
            throw ProviderAdapterError(
                providerID: "ollama-cloud",
                message: "Ollama session could not be created.",
                recoverySuggestion: "Save the Ollama account before starting the connection flow."
            )
        }
        return try await session(for: account).loadUsage(interactive: true)
    }

    func webView(for account: ProviderAccount) -> WKWebView? {
        guard account.webDataStoreID != nil else { return nil }
        return try? session(for: account).webView
    }

    func forgetSession(for account: ProviderAccount) {
        sessions.removeValue(forKey: account.id)
        guard let identifier = account.webDataStoreID else { return }
        WKWebsiteDataStore.remove(forIdentifier: identifier) { _ in }
    }

    private func session(for account: ProviderAccount) throws -> OllamaWebPageSession {
        guard let dataStoreID = account.webDataStoreID else {
            throw ProviderAdapterError(
                providerID: "ollama-cloud",
                message: "Ollama session is not connected.",
                recoverySuggestion: "Choose Connect Ollama and sign in through AI Limitbar."
            )
        }

        if let existing = sessions[account.id], existing.dataStoreID == dataStoreID {
            return existing
        }

        let created = OllamaWebPageSession(dataStoreID: dataStoreID)
        sessions[account.id] = created
        return created
    }
}

@MainActor
private final class OllamaWebPageSession: NSObject, WKNavigationDelegate {
    let dataStoreID: UUID
    let webView: WKWebView

    private let messageHandler: WeakScriptMessageHandler
    private var continuation: CheckedContinuation<OllamaUsagePagePayload, any Error>?
    private var timeoutTask: Task<Void, Never>?
    private var isInteractive = false
    private var hasReachedSettingsPage = false

    init(dataStoreID: UUID) {
        self.dataStoreID = dataStoreID

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = WKWebsiteDataStore(forIdentifier: dataStoreID)
        let userContentController = WKUserContentController()
        userContentController.addUserScript(
            WKUserScript(
                source: Self.usageUserScript,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            )
        )
        self.messageHandler = WeakScriptMessageHandler()
        configuration.userContentController = userContentController

        self.webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()

        messageHandler.owner = self
        userContentController.add(messageHandler, name: "ollamaUsage")
        webView.navigationDelegate = self
    }

    func loadUsage(interactive: Bool) async throws -> OllamaUsagePagePayload {
        guard continuation == nil else {
            throw ProviderAdapterError(
                providerID: "ollama-cloud",
                message: "Ollama connection is already loading.",
                recoverySuggestion: "Finish or cancel the current Ollama connection before refreshing again."
            )
        }

        isInteractive = interactive
        hasReachedSettingsPage = false
        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                if !interactive {
                    timeoutTask = Task { @MainActor [weak self] in
                        try? await Task.sleep(nanoseconds: 20_000_000_000)
                        guard !Task.isCancelled else { return }
                        self?.finish(
                            failure: ProviderAdapterError(
                                providerID: "ollama-cloud",
                                message: "Ollama settings page timed out.",
                                recoverySuggestion: "Reconnect Ollama and try again.",
                                isTransient: true
                            )
                        )
                    }
                } else {
                    // Interactive sign-in remains available until OAuth finishes
                    // or the user explicitly cancels the connection sheet.
                    timeoutTask = nil
                }
                webView.load(URLRequest(url: OllamaWebPageClientController.settingsURL))
            }
        }, onCancel: {
            Task { @MainActor [weak self] in
                self?.finish(failure: CancellationError())
            }
        })
    }

    func handleScriptMessage(_ message: WKScriptMessage) {
        guard message.name == "ollamaUsage",
              let body = message.body as? String,
              let data = body.data(using: .utf8)
        else {
            finish(
                failure: ProviderAdapterError(
                    providerID: "ollama-cloud",
                    message: "Ollama settings page returned an unsupported usage payload.",
                    recoverySuggestion: "Reconnect Ollama and check whether its settings page structure has changed."
                )
            )
            return
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            finish(success: try decoder.decode(OllamaUsagePagePayload.self, from: data))
        } catch {
            finish(
                failure: ProviderAdapterError(
                    providerID: "ollama-cloud",
                    message: "Ollama settings page returned malformed usage data.",
                    recoverySuggestion: "Reconnect Ollama and check whether its settings page structure has changed."
                )
            )
        }
    }

    private func finish(success payload: OllamaUsagePagePayload) {
        guard let continuation else { return }
        self.continuation = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        continuation.resume(returning: payload)
    }

    private func finish(failure error: Error) {
        guard let continuation else { return }
        self.continuation = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        webView.stopLoading()
        continuation.resume(throwing: error)
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
    ) {
        guard navigationAction.targetFrame?.isMainFrame == true else {
            decisionHandler(.allow)
            return
        }

        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }

        let isAllowed = OllamaWebPageNavigationPolicy.allowsMainFrameNavigation(
            url,
            interactive: isInteractive
        )
        guard isAllowed else {
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard continuation != nil else { return }
        guard let url = webView.url else {
            finish(
                failure: ProviderAdapterError(
                    providerID: "ollama-cloud",
                    message: "Ollama session is missing or expired.",
                    recoverySuggestion: "Reconnect Ollama through AI Limitbar."
                )
            )
            return
        }

        guard OllamaWebPageNavigationPolicy.isSettingsURL(url) else {
            guard !isInteractive else { return }
            finish(
                failure: ProviderAdapterError(
                    providerID: "ollama-cloud",
                    message: "Ollama session is missing or expired.",
                    recoverySuggestion: "Reconnect Ollama through AI Limitbar."
                )
            )
            return
        }

        hasReachedSettingsPage = true
        extractUsageFromSettingsPage()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        guard !OllamaWebPageNavigationFailurePolicy.shouldIgnore(
            error,
            currentURL: webView.url,
            hasReachedSettingsPage: hasReachedSettingsPage
        ) else {
            extractUsageFromSettingsPage()
            return
        }
        finish(
            failure: ProviderAdapterError(
                providerID: "ollama-cloud",
                message: "Ollama settings page failed to load.",
                recoverySuggestion: "Check the network connection and reconnect Ollama.",
                isTransient: true
            )
        )
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        self.webView(webView, didFail: navigation, withError: error)
    }

    private func extractUsageFromSettingsPage() {
        guard continuation != nil,
              let url = webView.url,
              OllamaWebPageNavigationPolicy.isSettingsURL(url)
        else { return }

        webView.evaluateJavaScript(Self.usageUserScript) { [weak self] _, error in
            guard let self, error != nil, self.continuation != nil else { return }
            self.finish(
                failure: ProviderAdapterError(
                    providerID: "ollama-cloud",
                    message: "Ollama settings page could not be inspected.",
                    recoverySuggestion: "Reconnect Ollama and try again.",
                    isTransient: true
                )
            )
        }
    }

    private static let usageUserScript = #"""
    (() => {
      if (window.location.origin !== "https://ollama.com" || window.location.pathname !== "/settings") {
        return;
      }

      const usageLabels = ["Session usage", "Weekly usage"];
      const percentPattern = /(\d+(?:\.\d+)?)\s*%/g;
      const textForLabel = (text, label, otherLabels) => {
        const labelIndex = text.indexOf(label);
        if (labelIndex < 0) return text;

        const nextLabelIndexes = otherLabels
          .map((otherLabel) => text.indexOf(otherLabel, labelIndex + label.length))
          .filter((index) => index >= 0);
        const nextLabelIndex = nextLabelIndexes.length > 0 ? Math.min(...nextLabelIndexes) : text.length;
        return text.slice(labelIndex, nextLabelIndex);
      };

      const parseResetAt = (text) => {
        const normalized = text.replace(/\s+/g, " ").trim();
        const relativeMatch = normalized.match(/(?:in|after)\s+(\d+(?:\.\d+)?)\s+(second|minute|hour|day|week)s?/i);
        if (relativeMatch) {
          const amount = Number(relativeMatch[1]);
          const unitMilliseconds = {
            second: 1_000,
            minute: 60_000,
            hour: 3_600_000,
            day: 86_400_000,
            week: 604_800_000
          }[relativeMatch[2].toLowerCase()];
          if (unitMilliseconds) return new Date(Date.now() + amount * unitMilliseconds).toISOString();
        }

        const resetMatch = normalized.match(/(?:reset|resets|renew|renews)\s*(?:on|at)?\s*:?\s*(.+)/i);
        if (resetMatch) {
          const timestamp = Date.parse(resetMatch[1]);
          if (!Number.isNaN(timestamp)) return new Date(timestamp).toISOString();
        }
        return null;
      };

      const sectionFor = (label) => {
        const anchor = Array.from(document.querySelectorAll("body *"))
          .find((element) => element.children.length === 0 && element.textContent?.trim() === label);
        if (!anchor) return null;

        const otherLabels = usageLabels.filter((candidate) => candidate !== label);
        let section = null;
        let candidate = anchor.parentElement;
        while (candidate && candidate !== document.body) {
          const candidateText = candidate.innerText || "";
          const candidatePercentages = candidateText.match(percentPattern) || [];
          const containsOtherUsageLabel = otherLabels.some((otherLabel) => candidateText.includes(otherLabel));
          if (candidateText.includes(label) && !containsOtherUsageLabel && candidatePercentages.length > 0) {
            section = candidate;
            break;
          }
          candidate = candidate.parentElement;
        }

        section = section || anchor.closest("section") || anchor.parentElement?.parentElement || anchor.parentElement;
        const text = section?.innerText || "";
        const sharedSection = anchor.closest("section");
        const sharedText = sharedSection?.innerText || "";
        const scopedText = textForLabel(text, label, otherLabels);
        const hasOtherUsageLabel = otherLabels.some((otherLabel) => text.includes(otherLabel));
        const percentMatch = scopedText.match(/(\d+(?:\.\d+)?)\s*%/) ||
          (!hasOtherUsageLabel ? text.match(/(\d+(?:\.\d+)?)\s*%/) : null);

        let resetSection = section;
        let parent = section?.parentElement;
        while (parent && parent !== document.body) {
          const parentText = parent.innerText || "";
          if (otherLabels.some((otherLabel) => parentText.includes(otherLabel))) break;
          if (parent.querySelector("time[datetime]") || /(?:reset|resets|renew|renews)/i.test(parentText)) {
            resetSection = parent;
            break;
          }
          parent = parent.parentElement;
        }

        let resetAt = null;
        const resetText = resetSection?.innerText || text;
        const resetScopedText = textForLabel(resetText, label, otherLabels);
        const timeElement = hasOtherUsageLabel ? null : resetSection?.querySelector("time[datetime]");
        const timeValue = timeElement?.getAttribute("datetime");
        if (timeValue && !Number.isNaN(Date.parse(timeValue))) {
          resetAt = new Date(timeValue).toISOString();
        }

        if (!resetAt && sharedSection && sharedSection !== resetSection) {
          const sharedTimeElements = Array.from(sharedSection.querySelectorAll("time[datetime]"));
          const usageIndex = usageLabels.indexOf(label);
          if (sharedTimeElements.length === usageLabels.length && usageIndex >= 0) {
            const sharedTimeValue = sharedTimeElements[usageIndex].getAttribute("datetime");
            if (sharedTimeValue && !Number.isNaN(Date.parse(sharedTimeValue))) {
              resetAt = new Date(sharedTimeValue).toISOString();
            }
          }
        }

        if (!resetAt) {
          resetAt = parseResetAt(resetScopedText);
        }
        if (!resetAt && sharedSection && sharedSection !== resetSection) {
          resetAt = parseResetAt(textForLabel(sharedText, label, otherLabels));
        }

        return {
          usedPercent: percentMatch ? Number(percentMatch[1]) : null,
          resetAt
        };
      };

      let delivered = false;
      const publishUsage = () => {
        if (delivered) return true;
        const session = sectionFor("Session usage");
        const weekly = sectionFor("Weekly usage");
        if (!session && !weekly) return false;

        delivered = true;
        window.webkit.messageHandlers.ollamaUsage.postMessage(JSON.stringify({ session, weekly }));
        return true;
      };

      if (!publishUsage()) {
        const observer = new MutationObserver(() => {
          if (publishUsage()) observer.disconnect();
        });
        observer.observe(document.documentElement, { childList: true, subtree: true, characterData: true });
        setTimeout(() => observer.disconnect(), 10_000);
      }
    })();
    """#
}

private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var owner: OllamaWebPageSession?

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        owner?.handleScriptMessage(message)
    }
}

enum OllamaWebPageNavigationPolicy {
    static func allowsMainFrameNavigation(_ url: URL, interactive: Bool) -> Bool {
        guard url.scheme == "https", let host = url.host?.lowercased() else { return false }

        if host == "ollama.com" || host.hasSuffix(".ollama.com") {
            return true
        }

        guard interactive else { return false }
        return host == "api.workos.com" ||
            host == "accounts.google.com" ||
            allowsRegionalGoogleAccountHost(host) ||
            host == "google.com" ||
            host.hasSuffix(".google.com") ||
            host == "github.com" ||
            host.hasSuffix(".github.com")
    }

    private static func allowsRegionalGoogleAccountHost(_ host: String) -> Bool {
        let prefix = "accounts.google."
        guard host.hasPrefix(prefix) else { return false }

        let suffixLabels = host
            .dropFirst(prefix.count)
            .split(separator: ".")
        if suffixLabels == ["com"] {
            return true
        }
        if suffixLabels.count == 1, suffixLabels[0].count == 2 {
            return true
        }
        return suffixLabels.count == 2 &&
            (suffixLabels[0] == "co" || suffixLabels[0] == "com") &&
            suffixLabels[1].count == 2
    }

    static func isSettingsURL(_ url: URL) -> Bool {
        url.scheme == "https" && url.host?.lowercased() == "ollama.com" && url.path == "/settings"
    }
}

enum OllamaWebPageNavigationFailurePolicy {
    static func shouldIgnore(
        _ error: Error,
        currentURL: URL?,
        hasReachedSettingsPage: Bool
    ) -> Bool {
        let error = error as NSError
        if error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
            return true
        }
        return hasReachedSettingsPage && currentURL.map(OllamaWebPageNavigationPolicy.isSettingsURL) == true
    }
}
