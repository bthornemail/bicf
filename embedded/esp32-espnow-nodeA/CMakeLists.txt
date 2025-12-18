cmake_minimum_required(VERSION 3.16)

set(EXTRA_COMPONENT_DIRS
  "../esp32-espnow-common/bicf_common"
)

include($ENV{IDF_PATH}/tools/cmake/project.cmake)
project(esp32_espnow_nodeA)

