import workshop
import Foundation

public class CloudClient: APIClient {
    
    internal var host: String
    internal var proto: String = "https"
    internal let session: URLSessionProtocol
    
    public init(host: String,
                proto: String? = nil,
                session: URLSessionProtocol = URLSession(configuration: .default))
    {
        self.host = host
        self.session = session
    }
    
    public func send<T>(_ request: T, completion: @escaping ResultCallback<T.Response>) where T: APIRequest {
        let req = self.urlRequest(for: request)
        let task = self.session.dataTask(with: req) { data, response, err in
            if let jsonData = data {
                do {
                    //print(String(data: jsonData, encoding: .utf8))
                    if let httpResponse = response as? HTTPURLResponse {
                        if httpResponse.statusCode == 200 {
                            let apiResponse = try JSONDecoder().decode(T.Response.self, from: jsonData)
                            completion(.success(apiResponse))
                        } else {
                            let errorResponse = try JSONDecoder().decode(APIResponseError.self,
                                                                         from: jsonData)
                            completion(.failure(errorResponse))
                        }
                    }
                } catch let err {
                    completion(.failure(err))
                }
            }
        }
        task.resume()
    }
    
    
    private func urlRequest<T: APIRequest>(for apiRequest: T) -> URLRequest {
        let url                         = self.endpoint(for: apiRequest)
        var request                     = URLRequest(url: url)
        request.httpMethod              = apiRequest.method.rawValue
        
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("pupil server: \(version)", forHTTPHeaderField: "User-Agent")
        
        if apiRequest.method == .post {
            do { request.httpBody = try JSONEncoder().encode(apiRequest) }
            catch let err { print("Error making request", err) }
        }
        return request
    }
    
    private func endpoint<T: APIRequest>(for request: T) -> URL {
        return URL(string: "\(proto)://\(host)/\(request.resourceName)")!
    }
}
