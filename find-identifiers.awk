#!/usr/bin/awk -f

BEGIN {
    current_class = ""
    current_object = ""
}

## Function
match($0, /^([a-z]\w+)\(.*\)/, a) { if (!seen[a[1]]++ && current_class == "") print a[1], "function", FILENAME, FNR }

## Verb
match($0, /^[A-Z]\w+\(([^)]+)\)\s*.*\s*:\s*.*$/, a) { if (!seen[a[1]]++) print a[1], "verb", FILENAME, FNR }

## Action
match($0, /^Define[TAI]+Action\(([^)]+)\)$/, a) { if (!seen[a[1]]++) print a[1], "action", FILENAME, FNR }

## Objects

### object
match($0, /^(\w+):\s*.*$/, a) {
    if (!seen[a[1]]++) {
        print a[1], "object", FILENAME, FNR
        current_object = a[1]
    }
}

### sub-object
match($0, /^\++\s+(\w+): .*$/, a) {
    if (!seen[a[1]]++) {
        print a[1], "sub-object", FILENAME, FNR
        current_object = a[1]
    }
}

## Classes

match($0, /^class (\w+):\s*.*$/, a) {
    if (!seen[a[1]]++) {
        current_class = a[1]
        print current_class, "class", FILENAME, FNR
    }
}

### properties (only show if in class or in object and first instance seen)
match($0, /^    ([a-z]\w+) = /, a) {
    if (current_class != "" || (current_object != "" && !seen[a[1]])) {
        print a[1], "property", FILENAME, FNR, current_class
        seen[a[1]]++
    }
}
### methods (only show if in class or in object and first instance seen)
match($0, /^\t([a-z]\w+)\(.*\)/, a) {
    if (current_class != "" || (current_object != "" && !seen[a[1]])) {
        print a[1], "method", FILENAME, FNR, current_class
        seen[a[1]]++
    }
}

## semicolons alone on a line end a class or object
/^\s*;\s*$/ {
    if (current_class != "") {
        current_class = ""
    } else if (current_object != "") {
        current_object = ""
    }
}
