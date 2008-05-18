FreeRtos Sources
================

Modifications
-------------
For using FreeRtos with Jfe threading abstraction, I made some following modifications:
- added functions to task.c to hold a pointer to Jfe::Thread instance
  - vTaskSetCurrentJfeThreadInstance()
  - xTaskGetCurrentJfeThreadInstance()
  - vTaskSetJfeThreadInstance()
  - xTaskGetJfeThreadInstance()
- added __cxa_get_globals() in task.c to correctly handle concurrent unwinding
- added xPortGetTotalHeapSize() (only for heap_4)
- added vPortGetHeapStatistics()
- added void checkStack(), getStackDepth()
- added assertion in vPortValidateInterruptPriority() to check if the caller is really an ISR and not a thread (but still not sure if this check is required)
- added assertion in vListInsertEnd() and vListInsert() to check if the element to be inserted is currently not owned by another list

