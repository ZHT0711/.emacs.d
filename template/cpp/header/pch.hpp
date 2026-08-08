#pragma once

#include "typemap.hpp"

#ifdef _WIN32
#include <SDKDDKVer.h>
#define UNICODE
#define NOMINMAX
#define VC_EXTRALEAN
#define WIN32_LEAN_AND_MEAN
#include <Windows.h>
#endif

#include <iostream>
