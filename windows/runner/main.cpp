#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "app_links/app_links_plugin_c_api.h"
#include "flutter_window.h"
#include "utils.h"

#include <string>

namespace {

#ifdef _DEBUG
bool SetRegistryString(const std::wstring &key, const wchar_t *name,
                       const std::wstring &value) {
  return ::RegSetKeyValueW(
             HKEY_CURRENT_USER, key.c_str(), name, REG_SZ, value.c_str(),
             static_cast<DWORD>((value.size() + 1) * sizeof(wchar_t))) ==
         ERROR_SUCCESS;
}

// Installers register the OAuth scheme; debug builds register themselves.
void RegisterDebugOAuthProtocol() {
  wchar_t exe_path[MAX_PATH];
  const DWORD length = ::GetModuleFileNameW(nullptr, exe_path, MAX_PATH);
  if (length == 0 || length == MAX_PATH) {
    return;
  }

  const std::wstring exe(exe_path, length);
  const std::wstring key =
      L"Software\\Classes\\com.comacasaencaplloc.popcorn-flutter";
  SetRegistryString(key, nullptr, L"URL:Popcorn authentication");
  SetRegistryString(key, L"URL Protocol", L"");
  SetRegistryString(key + L"\\DefaultIcon", nullptr, L"\"" + exe + L"\",0");
  SetRegistryString(key + L"\\shell\\open\\command", nullptr,
                    L"\"" + exe + L"\" \"%1\"");
}
#endif

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // OAuth launches a second process; deliver its link to the waiting app.
  if (SendAppLinkToInstance()) {
    return EXIT_SUCCESS;
  }

#ifdef _DEBUG
  RegisterDebugOAuthProtocol();
#endif

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(800, 800);
  if (!window.Create(L"Popcorn", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
