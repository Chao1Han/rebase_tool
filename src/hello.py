# Upstream refactored code
def hello(device="cpu"):
    """Generic hello for any device."""
    print(f"Hello from {device}!")

def hello_cuda():
    print("Hello from CUDA!")
