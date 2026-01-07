import re
import sys

TARGETS_FILE = "lib/core/targets.sh"

def patch_targets():
    with open(TARGETS_FILE, "r") as f:
        content = f.read()

    # Pattern: match 'baremetal) os_baremetal_FUNCTION ARGS ;;'
    # and insert k8s line after it.
    # Group 1: function suffix (deploy, remove, etc)
    # Group 2: arguments string
    pattern = r'(baremetal\) os_baremetal_(\w+)(.*) ;;)'
    
    def replacer(match):
        original_line = match.group(1)
        func_suffix = match.group(2)
        args = match.group(3)
        
        # k8s function uses os_k8s_PREFIX
        k8s_line = f'        k8s)     os_k8s_{func_suffix}{args} ;;'
        
        return f'{original_line}\n{k8s_line}'

    new_content = re.sub(pattern, replacer, content)
    
    if new_content == content:
        print("No changes made. Pattern might not match.")
        sys.exit(1)

    with open(TARGETS_FILE, "w") as f:
        f.write(new_content)
    
    print(f"Successfully patched {TARGETS_FILE}")

if __name__ == "__main__":
    patch_targets()
