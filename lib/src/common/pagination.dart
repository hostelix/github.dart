part of github.common;

/**
 * Internal Helper for dealing with GitHub Pagination
 */
class PaginationHelper<T> {
  final GitHub github;
  final List<http.Response> responses;
  final Completer<List<http.Response>> completer;
  
  PaginationHelper(this.github) : responses = [], completer = new Completer<List<http.Response>>();
  
  Future<List<http.Response>> fetch(String method, String path, {int pages, Map<String, String> headers, Map<String, dynamic> params, String body}) {
    Future<http.Response> actualFetch(String realPath) {
      return github.request(method, realPath, headers: headers, params: params, body: body);
    }
    
    void done() => completer.complete(responses);
    
    var count = 0;
    
    var handleResponse;
    handleResponse = (http.Response response) {
      count++;
      responses.add(response);
      
      if (!response.headers.containsKey("link")) {
        done();
        return;
      }
      
      var info = parseLinkHeader(response.headers['link']);
      
      if (!info.containsKey("next")) {
        done();
        return;
      }
      
      if (pages != null && count == pages) {
        done();
        return;
      }
      
      var nextUrl = info['next'];
      
      actualFetch(nextUrl).then(handleResponse);
    };
    
    actualFetch(path).then(handleResponse);
    
    return completer.future;
  }
  
  Stream<http.Response> fetchStreamed(String method, String path, {int pages, Map<String, String> headers, Map<String, dynamic> params, String body}) {
    var controller = new StreamController.broadcast();
    
    Future<http.Response> actualFetch(String realPath) {
      return github.request(method, realPath, headers: headers, params: params, body: body);
    }
    
    var count = 0;
    
    var handleResponse;
    handleResponse = (http.Response response) {
      count++;
      controller.add(response);
      
      if (!response.headers.containsKey("link")) {
        controller.close();
        return;
      }
      
      var info = parseLinkHeader(response.headers['link']);
      
      if (!info.containsKey("next")) {
        controller.close();
        return;
      }
      
      if (pages != null && count == pages) {
        controller.close();
        return;
      }
      
      var nextUrl = info['next'];
      
      actualFetch(nextUrl).then(handleResponse);
    };
    
    actualFetch(path).then(handleResponse);
    
    return controller.stream;
  }
  
  Stream<T> objects(String method, String path, JSONConverter converter, {int pages, Map<String, String> headers, Map<String, dynamic> params, String body}) {
    var controller = new StreamController();
    fetchStreamed(method, path, pages: pages, headers: headers, params: params, body: body).listen((response) {
      var json = JSON.decode(response.body);
      for (var item in json) {
        controller.add(converter(github, item));
      }
    }).onDone(() => controller.close());
    return controller.stream;
  }
}