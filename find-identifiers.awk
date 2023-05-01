#!/usr/bin/awk -f

match($0, /^(\w+):\s*.*$/, a) { if (!seen[a[1]]++) print a[1], "object", FILENAME }
match($0, /^class (\w+):\s*.*$/, a) { if (!seen[a[1]]++) print a[1], "class", FILENAME }
match($0, /^([a-z]\w+)\(.*\)/, a) { if (!seen[a[1]]++) print a[1], "function", FILENAME }
match($0, /^[ \t]+([a-z]\w+)\(.*\)/, a) { if (!seen[a[1]]++) print a[1], "method", FILENAME }
match($0, /^[A-Z]\w+\(([^)]+)\)\s*.*\s*:\s*.*$/, a) { if (!seen[a[1]]++) print a[1], "verb", FILENAME }
match($0, /^Define[TAI]+Action\(([^)]+)\)$/, a) { if (!seen[a[1]]++) print a[1], "action", FILENAME }
match($0, /^\++\s+(\w+): .*$/, a) { if (!seen[a[1]]++) print a[1], "sub-object", FILENAME }
match($0, /^[ \t]+([a-z]\w+) = /, a) { if (!seen[a[1]]++) print a[1], "property", FILENAME }
