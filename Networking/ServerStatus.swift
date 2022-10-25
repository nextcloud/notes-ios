//
//  ServerStatus.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 10/24/22.
//  Copyright © 2022 Peter Hedlund. All rights reserved.
//

import Foundation
import OpenSSL

class ServerStatus: NSObject {
    static let shared = ServerStatus()

    var session = URLSession(configuration: .default)

    override init() {
        super.init()
        session = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue())
    }

    func check() async throws  {
        let router = StatusRouter.status
        do {
            let (_, _) = try await session.data(for: router.asURLRequest())
        } catch(let error) {
            throw error as NSError
        }
    }

    func reset() {
        KeychainHelper.allowUntrustedCertificate = false
        if let directory = ServerStatus.certificatesDirectory {
            do {
                try FileManager.default.removeItem(at: directory)
            } catch { }
        }
    }

    static var certificatesDirectory: URL? {
        let directory = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first
        do {
            let url = directory!.appendingPathComponent( "Certificates", isDirectory: true)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            return url
        } catch  {
            return nil
        }
    }

    func savedCert(host: String) -> SecCertificate? {
        if let directory = ServerStatus.certificatesDirectory {
            let certificateDerPath = directory.appendingPathComponent(host).appendingPathExtension("der")
            if let data = NSData(contentsOf: certificateDerPath) {
                return SecCertificateCreateWithData(kCFAllocatorDefault, data)
            } else {
                return nil
            }
        }
        return nil
    }

    private func checkTrustedChallenge(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge) -> Bool {
        let protectionSpace = challenge.protectionSpace
        let directoryCertificate = ServerStatus.certificatesDirectory!
        let host = challenge.protectionSpace.host
        let certificateSavedPath = directoryCertificate.appendingPathComponent(host).appendingPathExtension("der")
        var isTrusted: Bool

        if let serverTrust: SecTrust = protectionSpace.serverTrust, let certificate = SecTrustGetCertificateAtIndex(serverTrust, 0)  {
            // extract certificate txt
            saveX509Certificate(certificate, host: host, directoryCertificate: directoryCertificate.path)

            var secresult = SecTrustResultType.invalid
            let status = SecTrustEvaluate(serverTrust, &secresult)
            let isServerTrusted = SecTrustEvaluateWithError(serverTrust, nil)

            let certificateCopyData = SecCertificateCopyData(certificate)
            let data = CFDataGetBytePtr(certificateCopyData);
            let size = CFDataGetLength(certificateCopyData);
            let certificateData = NSData(bytes: data, length: size)

            certificateData.write(to: directoryCertificate.appendingPathComponent(host).appendingPathExtension("tmp"), atomically: true)

            if isServerTrusted {
                isTrusted = true
            } else if status == errSecSuccess, let certificateDataSaved = NSData(contentsOf: certificateSavedPath), certificateData.isEqual(to: certificateDataSaved as Data) {
                isTrusted = true
            } else {
                isTrusted = false
            }
        } else {
            isTrusted = false
        }

        return isTrusted
    }

    func writeCertificate(host: String) {
        let directoryCertificate = ServerStatus.certificatesDirectory!
        let certificateAtPath = directoryCertificate.appendingPathComponent(host).appendingPathExtension("tmp")
        let certificateToPath = directoryCertificate.appendingPathComponent(host).appendingPathExtension("der")

        do {
            try FileManager.default.moveItem(at: certificateAtPath, to: certificateToPath)
        } catch (let error) {
            print(error.localizedDescription)
        }
    }

    func certificateText(_ host: String) -> String {
        let directoryCertificate = ServerStatus.certificatesDirectory!
        let certificateTxtPath = directoryCertificate.appendingPathComponent(host).appendingPathExtension("txt")
        do {
            return try String(contentsOf: certificateTxtPath)
        } catch {
            return ""
        }
    }

    private func saveX509Certificate(_ certificate: SecCertificate, host: String, directoryCertificate: String) {
        let certNamePathTXT = directoryCertificate + "/" + host + ".txt"
        let data: CFData = SecCertificateCopyData(certificate)
        let mem = BIO_new_mem_buf(CFDataGetBytePtr(data), Int32(CFDataGetLength(data)))
        let x509cert = d2i_X509_bio(mem, nil)

        if x509cert == nil {
            print("[LOG] OpenSSL couldn't parse X509 Certificate")
        } else {
            // save details
            if FileManager.default.fileExists(atPath: certNamePathTXT) {
                do {
                    try FileManager.default.removeItem(atPath: certNamePathTXT)
                } catch { }
            }
            let fileCertInfo = fopen(certNamePathTXT, "w")
            if fileCertInfo != nil {
                let output = BIO_new_fp(fileCertInfo, BIO_NOCLOSE)
                X509_print_ex(output, x509cert, UInt(XN_FLAG_COMPAT), UInt(X509_FLAG_COMPAT))
                BIO_free(output)
            }
            fclose(fileCertInfo)
            X509_free(x509cert)
        }

        BIO_free(mem)
    }

}

extension ServerStatus: URLSessionDelegate {

    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if checkTrustedChallenge(session, didReceive: challenge) {
            completionHandler(URLSession.AuthChallengeDisposition.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
        } else {
            completionHandler(URLSession.AuthChallengeDisposition.performDefaultHandling, nil)
        }
    }

}
