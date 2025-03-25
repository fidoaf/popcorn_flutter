abstract class IWebRenderer {
  Future<bool> launch(String url);
  Future<bool> check(String url);

  const IWebRenderer();
}