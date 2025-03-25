enum BrowserType {
  chrome(path: r'C:\Program Files\Google\Chrome\Application\chrome.exe'),
  chromium(path: r'C:\chromium\chrome.exe'),
  edge(path: r'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe');

  final String path;
  const BrowserType({required this.path});

  static BrowserType fromString(String value) => BrowserType.values.firstWhere((bt) => bt.name == value, orElse: () => BrowserType.values.first);
}
