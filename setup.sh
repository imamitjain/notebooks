#!/usr/bin/env bash
set -euo pipefail

KERNEL_NAME="notebooks"
ENV_NAME="p3"
MAMBA_ROOT="${MAMBA_ROOT_PREFIX:-$HOME/.micromamba}"
ENV_DIR="$MAMBA_ROOT/envs/$ENV_NAME"
ENV_PYTHON="$ENV_DIR/bin/python"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "$SCRIPT_DIR"

info()  { printf "\n\033[1;34m==>\033[0m \033[1m%s\033[0m\n" "$1"; }
ok()    { printf "\033[1;32m  ✓\033[0m %s\n" "$1"; }
fail()  { printf "\033[1;31m  ✗\033[0m %s\n" "$1"; exit 1; }

# ── 1. Check prerequisites ──────────────────────────────────────────
info "Checking prerequisites"

if ! command -v brew &>/dev/null; then
    fail "Homebrew not found. Install it from https://brew.sh"
fi
ok "Homebrew"

if ! command -v micromamba &>/dev/null; then
    info "Installing micromamba"
    brew install micromamba
else
    ok "micromamba already installed"
fi

# ── 2. Ensure micromamba p3 environment exists ───────────────────────
info "Checking micromamba environment '${ENV_NAME}'"

if [ ! -d "$ENV_DIR" ]; then
    info "Creating micromamba environment '${ENV_NAME}'"
    micromamba create -n "$ENV_NAME" python=3.11 -y -c conda-forge
fi
ok "Environment '${ENV_NAME}' ready ($("$ENV_PYTHON" --version))"

# ── 3. Install Python packages ──────────────────────────────────────
info "Installing Python packages from requirements.txt"

micromamba run -n "$ENV_NAME" pip install -r requirements.txt

ok "All Python packages installed"

# ── 4. Register Jupyter kernel ──────────────────────────────────────
PYTHON_VERSION="$("$ENV_PYTHON" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
KERNEL_DISPLAY="Notebooks (Python ${PYTHON_VERSION})"

info "Registering Jupyter kernel"

micromamba run -n "$ENV_NAME" python -m ipykernel install \
    --user \
    --name "$KERNEL_NAME" \
    --display-name "$KERNEL_DISPLAY"

ok "Kernel '${KERNEL_NAME}' registered"

# ── 5. Go + gophernotes (optional) ──────────────────────────────────
info "Setting up Go kernel (gophernotes)"

if ! command -v go &>/dev/null; then
    echo "  Go not found — installing via Homebrew"
    brew install go
else
    ok "Go already installed ($(go version | awk '{print $3}'))"
fi

GOPATH="${GOPATH:-$HOME/go}"
GOPHERNOTES_BIN="$GOPATH/bin/gophernotes"

if [ ! -f "$GOPHERNOTES_BIN" ]; then
    echo "  Installing gophernotes..."
    go install github.com/gopherdata/gophernotes@latest
else
    ok "gophernotes already installed"
fi

KERNEL_DIR="$HOME/Library/Jupyter/kernels/gophernotes"
if [ ! -d "$KERNEL_DIR" ]; then
    mkdir -p "$KERNEL_DIR"
    cat > "$KERNEL_DIR/kernel.json" <<GOKERNEL
{
    "argv": ["${GOPHERNOTES_BIN}", "{connection_file}"],
    "display_name": "Go (gophernotes)",
    "language": "go",
    "interrupt_mode": "message",
    "metadata": {}
}
GOKERNEL
    ok "gophernotes kernel spec installed"
else
    ok "gophernotes kernel spec already exists"
fi

# ── 6. Create project directories ───────────────────────────────────
info "Creating project directories"

dirs=(
    "01-python-for-ml"
    "02-ml-fundamentals"
    "03-deep-learning"
    "04-llm-and-transformers"
    "05-golang"
    "data"
)

for d in "${dirs[@]}"; do
    mkdir -p "$d"
done
touch data/.gitkeep

ok "Directory structure ready"

# ── 7. Verify ────────────────────────────────────────────────────────
info "Verifying installation"

echo ""
echo "  Jupyter kernels:"
micromamba run -n "$ENV_NAME" jupyter kernelspec list 2>/dev/null | sed 's/^/    /'
echo ""

info "Setup complete"
echo ""
echo "  To get started:"
echo "    micromamba activate ${ENV_NAME}"
echo "    jupyter notebook"
echo ""
