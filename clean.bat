@echo off

del /Q jt.def 2> nul
del /Q jt.ksp 2> nul
del /Q jt.map 2> nul
del /Q jt.rsp 2> nul
if exist obj (
  del /Q obj\*.obj 2> nul
)
