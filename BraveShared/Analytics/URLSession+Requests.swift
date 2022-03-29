// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Foundation
import Shared

extension URLSession {
  @discardableResult
  public func request(
    _ url: URL,
    method: HTTPMethod = .get,
    parameters: [String: Any],
    encoding: ParameterEncoding = .query,
    _ completion: @escaping (Result<Any, Error>) -> Void
  ) -> URLSessionDataTask! {
    do {
      let request = try buildRequest(
        url,
        method: method,
        parameters: parameters,
        encoding: encoding)

      let task = self.dataTask(with: request) { data, response, error in
        if let error = error {
          return completion(.failure(error))
        }

        guard let data = data else {
          return completion(.failure(NSError(domain: "com.brave.url.session.build-request", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data returned from the server"])))
        }

        do {
          completion(.success(try JSONSerialization.jsonObject(with: data, options: .mutableLeaves)))
        } catch {
          completion(.failure(error))
        }
      }
      task.resume()
      return task
    } catch {
      Log.main.error("\(error.localizedDescription)")
      return nil
    }
  }
}

extension URLSession {
  public enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case head = "HEAD"
    case delete = "DELETE"
  }

  public enum ParameterEncoding {
    case json
    case query
  }

  private func buildRequest(
    _ url: URL,
    method: HTTPMethod,
    headers: [String: String] = [:],
    parameters: [String: Any],
    encoding: ParameterEncoding
  ) throws -> URLRequest {

    var request = URLRequest(url: url)
    request.httpMethod = method.rawValue
    headers.forEach({ request.setValue($0.value, forHTTPHeaderField: $0.key) })
    switch encoding {
    case .json:
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: .prettyPrinted)

    case .query:
      var queryParameters = [URLQueryItem]()
      for item in parameters {
        if let value = item.value as? String {
          queryParameters.append(URLQueryItem(name: item.key, value: value))
        } else {
          throw NSError(
            domain: "com.brave.url.session.build-request", code: -1,
            userInfo: [
              NSLocalizedDescriptionKey: "Invalid Parameter cannot be serialized to query url: \(item.key)"
            ])
        }
      }

      var urlComponents = URLComponents()
      urlComponents.scheme = request.url?.scheme
      urlComponents.host = request.url?.host
      urlComponents.path = request.url?.path ?? ""
      urlComponents.queryItems = queryParameters
      request.url = urlComponents.url
      request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
      request.httpBody = nil
    }

    return request
  }
}
