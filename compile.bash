#!/bin/bash

rm ./**/*.elc
rm *.elc

for file in ./*.el; do
    echo 'Compiling '"$file"' ...'
    cask emacs -batch -L . --eval '(setq byte-compile-error-on-warn t)' -f batch-byte-compile "$file" || break
done

for file in ./**/*.el; do
    echo 'Compiling '"$file"' ...'
    cask emacs -batch -L . --eval '(setq byte-compile-error-on-warn t)' -f batch-byte-compile "$file" || break
done

if [[ -z $NO_REMOVE_ELC ]]; then
    rm ./**/*.elc
    rm *.elc
fi
