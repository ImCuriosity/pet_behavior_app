@echo off
set PROTOC_DIR=./lib/protobuf
set OUTPUT_DIR=./lib/protos

if not exist %OUTPUT_DIR% mkdir %OUTPUT_DIR%

protoc --dart_out=%OUTPUT_DIR% -I %PROTOC_DIR% %PROTOC_DIR%/pet_analysis.proto

echo.
echo Protobuf Dart files generated successfully in %OUTPUT_DIR%!
pause