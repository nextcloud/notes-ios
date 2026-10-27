// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Synchronization

///
/// Routes requests to the ``FakeNotesServer`` registered for the token in the first path component.
///
/// Every test uses its own token (`http://127.0.0.1:9/<token>`), so a late response can never reach another test.
///
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    private static let servers = Mutex<[String: FakeNotesServer]>([:])

    static func register(_ server: FakeNotesServer, token: String) {
        servers.withLock { $0[token] = server }
    }

    static func unregister(token: String) {
        _ = servers.withLock { $0.removeValue(forKey: token) }
    }

    private let isStopped = Mutex(false)

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        var request = self.request

        if request.httpBody == nil, let stream = request.httpBodyStream {
            request.httpBody = Self.readAll(stream)
        }

        guard let token = request.url?.pathComponents.dropFirst().first,
              let server = Self.servers.withLock({ $0[token] }) else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }

        let reply = server.handle(request, token: token)

        guard let delay = reply.delay else {
            deliver(reply)
            return
        }

        // Deliver on the loading thread's run loop, as the URL loading system expects.
        let runLoop = UncheckedSendable(CFRunLoopGetCurrent())

        DispatchQueue.global().asyncAfter(deadline: .now() + delay.timeInterval) { [self] in
            CFRunLoopPerformBlock(runLoop.value, CFRunLoopMode.commonModes.rawValue) {
                self.deliver(reply)
            }

            CFRunLoopWakeUp(runLoop.value)
        }
    }

    override func stopLoading() {
        isStopped.withLock { $0 = true }
    }

    private func deliver(_ reply: FakeNotesServer.Reply) {
        guard !isStopped.withLock({ $0 }) else { return }

        switch reply.outcome {
            case let .response(response, body):
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)

                if !body.isEmpty {
                    client?.urlProtocol(self, didLoad: body)
                }

                client?.urlProtocolDidFinishLoading(self)
            case let .failure(error):
                client?.urlProtocol(self, didFailWithError: error)
        }
    }

    /// A URLProtocol sees bodies as streams; test bodies are small and in memory, so reading them synchronously is fine.
    private static func readAll(_ stream: InputStream) -> Data {
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)

        stream.open()

        defer {
            stream.close()
        }

        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)

            guard count > 0 else { break }

            data.append(buffer, count: count)
        }

        return data
    }
}

struct UncheckedSendable<Value>: @unchecked Sendable {
    let value: Value

    init(_ value: Value) {
        self.value = value
    }
}

extension Duration {
    var timeInterval: TimeInterval {
        let (seconds, attoseconds) = components
        return TimeInterval(seconds) + TimeInterval(attoseconds) / 1e18
    }
}
