#!/bin/bash

echo "=== ZSH Startup Time Optimization Analysis ==="
echo

# Measure baseline
echo "Current startup time:"
time zsh -i -c exit 2>&1 | grep real

echo
echo "Common optimizations you can apply:"
echo

echo "1. Compile your zshrc for faster loading:"
echo "   zcompile ~/.zshrc"
echo

echo "2. Check for slow completions:"
for i in 1 2 3; do
    /usr/bin/time zsh -i -c exit 2>&1 | grep real
done

echo
echo "3. Analyzing your configuration..."

# Check for common slow operations
echo
echo "Checking for potentially slow operations in .zshrc:"
grep -n "brew shellenv\|pyenv init\|rbenv init\|nvm\|rvm\|conda\|eval\|source" ~/.zshrc 2>/dev/null || echo "None found in .zshrc"

echo
echo "4. Lazy loading suggestions:"
echo "   - Move 'brew shellenv' to only run when needed"
echo "   - Lazy load pyenv, rbenv, nvm, etc."
echo "   - Use zsh-defer for non-critical plugins"
echo "   - Compile completion dumps: rm ~/.zcompdump && compinit"

echo
echo "5. Quick wins:"
echo "   - Remove duplicate PATH entries"
echo "   - Skip compinit safety check: compinit -C"
echo "   - Use faster prompt themes"
echo "   - Defer non-essential module loading"

echo
echo "Running detailed profiling (this will take a moment)..."
PROFILE_STARTUP=1 zsh -i -c exit 2>&1 | head -100