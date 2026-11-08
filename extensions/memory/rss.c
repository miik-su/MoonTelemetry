#include <stdint.h>
#include <moonbit.h>
#if defined(_WIN32)
#include <windows.h>
#include <psapi.h>
MOONBIT_FFI_EXPORT int64_t moontelemetry_current_rss(void) {
  typedef BOOL (WINAPI *memory_fn)(HANDLE, PPROCESS_MEMORY_COUNTERS, DWORD);
  HMODULE module = GetModuleHandleW(L"kernel32.dll");
  if (!module) return -1;
  memory_fn query = (memory_fn)GetProcAddress(module, "K32GetProcessMemoryInfo");
  PROCESS_MEMORY_COUNTERS counters = {0};
  counters.cb = sizeof(counters);
  if (!query || !query(GetCurrentProcess(), &counters, sizeof(counters))) return -1;
  if ((uint64_t)counters.WorkingSetSize > INT64_MAX) return -1;
  return (int64_t)counters.WorkingSetSize;
}
#elif defined(__linux__)
#include <stdio.h>
#include <unistd.h>
MOONBIT_FFI_EXPORT int64_t moontelemetry_current_rss(void) {
  FILE *file = fopen("/proc/self/statm", "r");
  unsigned long long total = 0, resident = 0;
  if (!file) return -1;
  int read = fscanf(file, "%llu %llu", &total, &resident);
  fclose(file);
  long page = sysconf(_SC_PAGESIZE);
  if (read != 2 || page <= 0 || resident > (uint64_t)INT64_MAX/(uint64_t)page) return -1;
  return (int64_t)(resident * (uint64_t)page);
}
#elif defined(__APPLE__)
#include <mach/mach.h>
MOONBIT_FFI_EXPORT int64_t moontelemetry_current_rss(void) {
  mach_task_basic_info_data_t info;
  mach_msg_type_number_t count = MACH_TASK_BASIC_INFO_COUNT;
  if (task_info(mach_task_self(), MACH_TASK_BASIC_INFO, (task_info_t)&info, &count) != KERN_SUCCESS) return -1;
  if ((uint64_t)info.resident_size > INT64_MAX) return -1;
  return (int64_t)info.resident_size;
}
#else
MOONBIT_FFI_EXPORT int64_t moontelemetry_current_rss(void) { return -1; }
#endif
