#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

namespace {

// Process-wide mitigations, applied before any other code runs.
//
// DLLs load only from the application directory and System32, not from the
// working directory or PATH, so a DLL planted there is never picked up. None
// may come from a network share or a low-integrity file, and System32's copy
// wins over a same-named DLL dropped next to the app. The app opens its own
// DLLs by bare name from its directory, and Windows' by System32 path, so
// neither is affected.
//
// Not hardware shadow stacks (/CETCOMPAT): the Dart VM unwinds to an
// exception handler by resetting the stack pointer, which a shadow stack
// rejects.
void HardenProcess() {
  ::SetDefaultDllDirectories(LOAD_LIBRARY_SEARCH_DEFAULT_DIRS);

  PROCESS_MITIGATION_IMAGE_LOAD_POLICY image_load = {};
  image_load.NoRemoteImages = 1;
  image_load.NoLowMandatoryLabelImages = 1;
  image_load.PreferSystem32Images = 1;
  ::SetProcessMitigationPolicy(ProcessImageLoadPolicy, &image_load,
                               sizeof(image_load));

  // End the process on heap corruption rather than carry on.
  ::HeapSetInformation(nullptr, HeapEnableTerminationOnCorruption, nullptr, 0);
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  HardenProcess();

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
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"Skylight Wallet", origin, size)) {
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
