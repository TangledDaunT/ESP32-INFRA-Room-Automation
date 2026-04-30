import os
import re

src_dir = "src"
out_dir = "OpenClawFirmware"
out_file = os.path.join(out_dir, "OpenClawFirmware.ino")

os.makedirs(out_dir, exist_ok=True)

headers = ["config.h", "dashboard.h", "hardware.h", "smoke_tracker.h", "automation.h", "network.h", "webserver.h", "mqtt_client.h", "sensors.h"]
cpps = ["hardware.cpp", "smoke_tracker.cpp", "automation.cpp", "network.cpp", "webserver.cpp", "mqtt_client.cpp", "main.cpp"]

combined = ""
command_handler_defined = False

for file in headers + cpps:
    path = os.path.join(src_dir, file)
    with open(path, "r") as f:
        lines = f.readlines()
        
    combined += f"// =========================================\n"
    combined += f"//  {file}\n"
    combined += f"// =========================================\n"
    for line in lines:
        if re.match(r'^\s*#pragma\s+once', line):
            continue
        if re.match(r'^\s*#include\s+"', line):
            continue
        if "typedef void (*CommandHandler)" in line:
            if command_handler_defined:
                continue
            command_handler_defined = True
        combined += line
    combined += f"\n\n"

with open(out_file, "w") as f:
    f.write(combined)
print(f"Successfully generated {out_file}")
