; phpinspect-imports.el --- PHP parsing and completion package  -*- lexical-binding: t; -*-

;; Copyright (C) 2021-2023  Free Software Foundation, Inc

;; Author: Hugo Thunnissen <devel@hugot.nl>
;; Keywords: php, languages, tools, convenience
;; Version: 0

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; See docstrings for documentation, starting with `phpinspect-mode'.

;;; Code:

(require 'phpinspect-token-predicates)
(require 'phpinspect-index)
(require 'phpinspect-autoload)
(require 'phpinspect-buffer)
(require 'phpinspect-cache)
(require 'phpinspect-util)
(require 'phpinspect-type)

(defun phpinspect-insert-at-point (point data)
  (save-excursion
    (goto-char point)
    (insert data)))

(defun phpinspect-find-first-use (token-meta)
  (if (and (phpinspect-namespace-p (phpinspect-meta-token token-meta))
           (phpinspect-namespace-is-blocked-p (phpinspect-meta-token token-meta)))
      (phpinspect-find-first-use (phpinspect-meta-last-child token-meta))
    (phpinspect-meta-find-first-child-matching
     token-meta (phpinspect-meta-wrap-token-pred #'phpinspect-use-p))))

(defun phpinspect-add-use (fqn buffer &optional namespace-meta)
  "Add use statement for FQN to BUFFER.

If NAMESPACE-TOKEN is non-nil, it is assumed to be a token that
was parsed from BUFFER and its location will be used to find a
buffer position to insert the use statement at."
  (when (string-match "^\\\\" fqn)
    (setq fqn (string-trim-left fqn "\\\\")))

  (if namespace-meta
      (let* ((namespace-block (and (phpinspect-namespace-is-blocked-p
                                    (phpinspect-meta-token namespace-meta))
                                   (phpinspect-meta-last-child namespace-meta)))
             (existing-use (phpinspect-find-first-use namespace-meta)))
        (if existing-use
            (phpinspect-insert-at-point
             (phpinspect-meta-start existing-use) (format "use %s;%c" fqn ?\n))
          (if namespace-block
              (phpinspect-insert-at-point
               (+ 1 (phpinspect-meta-start namespace-block))
               (format "%c%cuse %s;%c" ?\n ?\n fqn ?\n))
            (phpinspect-insert-at-point
             (phpinspect-meta-end
              (phpinspect-meta-find-first-child-matching
               namespace-meta (phpinspect-meta-wrap-token-pred #'phpinspect-terminator-p)))
             (format "%c%cuse %s;%c" ?\n ?\n fqn ?\n)))))
    ;; else
    (let ((existing-use (phpinspect-meta-find-first-child-matching
                         (phpinspect-buffer-root-meta buffer)
                        (phpinspect-meta-wrap-token-pred #'phpinspect-use-p))))
      (if existing-use
          (phpinspect-insert-at-point
           (phpinspect-meta-start existing-use)
           (format "use %s;%c" fqn ?\n))
        (let* ((first-token (phpinspect-meta-first-child (phpinspect-buffer-root-meta buffer)))
               token-after)
          (when (and (phpinspect-word-p (phpinspect-meta-token first-token))
                     (string= "declare" (cadr (phpinspect-meta-token first-token))))
            (progn
              (setq token-after first-token)
              (while (and token-after (not (phpinspect-terminator-p
                                            (phpinspect-meta-token token-after))))
                (setq token-after (phpinspect-meta-find-right-sibling token-after)))))
          (if token-after
              (phpinspect-insert-at-point
               (phpinspect-meta-end token-after) (format "%c%cuse %s;%c" ?\n ?\n fqn ?\n))
            (phpinspect-insert-at-point
             (phpinspect-meta-start first-token)
             (format "%c%cuse %s;%c%c" ?\n ?\n fqn ?\n ?\n))))))))

(defun phpinspect-add-use-interactive (typename buffer project &optional namespace-token)
  (let* ((autoloader (phpinspect-project-autoload project))
         (fqns (phpinspect-autoloader-get-type-bag autoloader typename)))
    (cond ((= 1 (length fqns))
           (phpinspect-add-use (phpinspect-name-string (car fqns)) buffer namespace-token))
          ((> (length fqns) 1)
           (phpinspect-add-use (completing-read "Class: " (phpinspect-names-to-alist fqns))
                               buffer namespace-token))
          (t (phpinspect-message "No import found for type %s" typename)))))

(defun phpinspect-namespace-part-of-typename (typename)
  (string-trim-right typename "\\\\?[^\\]+"))

(defalias 'phpinspect-fix-uses-interactive #'phpinspect-fix-imports
  "Alias for backwards compatibility")

(defsubst phpinspect-namespace-meta-body (namespace-meta)
  "Return the token metadata of NAMESPACE-META's body.
More specifically, returns the token itself if it is a namespace
without block.  If the namespace is defined with a block ('{}'),
NAMESPACE-META itself is returned without alterations."
  (if (phpinspect-block-p (caddr (phpinspect-meta-token namespace-meta)))
      (phpinspect-meta-find-first-child-matching-token namespace-meta #'phpinspect-block-p)
    namespace-meta))

(defun phpinspect-find-use-statement-for-import (parent-token import-type)
  (phpinspect-meta-find-first-child-matching-token
   (if (phpinspect-namespace-p (phpinspect-meta-token parent-token))
       (phpinspect-namespace-meta-body parent-token)
     parent-token)
   (lambda (token)
     (and (phpinspect-use-p token)
          (phpinspect-word-p (cadr token))
          (phpinspect--type= import-type (phpinspect-use-name-to-type (cadadr token)))))))

(defun phpinspect-remove-unneeded-use-statements (types buffer imports parent-token)
  (dolist (import imports)
    ;; Namespace must be inferred within the loop, see comments in
    ;; `phpinspect-add-use-statements-for-missing-types' for context.
    (let ((namespace (phpinspect-meta-find-parent-matching-token parent-token #'phpinspect-namespace-p)))
      (unless (member (car import) types)
        (when-let ((use-meta (phpinspect-find-use-statement-for-import namespace (cdr import))))
          (let ((start-point (phpinspect-meta-start use-meta))
                (use-before (phpinspect-meta-find-left-sibling use-meta)))
            (if (phpinspect-use-p (phpinspect-meta-token use-before))
                ;; left-sibling is another use statement, remove all preceding whitespace
                (setq start-point (- start-point (length (phpinspect-meta-whitespace-before use-meta))))
              ;; left-sibling isn't a use statement, just remove a newline if
              ;; any whitespace is present
              (when (length> (phpinspect-meta-whitespace-before use-meta) 0)
                (setq start-point (- start-point 1))))

            (delete-region start-point (phpinspect-meta-end use-meta))
            (phpinspect-buffer-parse buffer 'no-interrupt)))))))

(defun phpinspect-add-use-statements-for-missing-types (types buffer imports project parent-token)
  "Add use statements to BUFFER for TYPES if not already included in IMPORTS.

Uses PROJECT's autoloader to determine available types for import.

PARENT-TOKEN must be a `token-meta' object and is used to
determine the scope of the imports (global or local namespace)."
  (dolist (type types)
    ;; Namespace token must be inferred within the loop, as the ancestors of
    ;; PARENT-TOKEN may change after a buffer reparse (which happens after each
    ;; insert)
    (let* ((namespace (phpinspect-meta-find-parent-matching-token
                       parent-token #'phpinspect-namespace-p))
           (namespace-name (if namespace
                               (phpinspect-namespace-name (phpinspect-meta-token namespace))
                             "")))

      ;; Add use statements for types that aren't imported or already referenced
      ;; with a fully qualified name.
      (unless (or (or (alist-get type imports))
                  (gethash (phpinspect-intern-name
                            (phpinspect--resolve-type-name
                             nil namespace-name (phpinspect-name-string type)))
                           (phpinspect-autoloader-types
                            (phpinspect-project-autoload project))))
        (unless (member (phpinspect-name-string type) phpinspect-native-typenames)
          (phpinspect-add-use-interactive type buffer project namespace)
          (phpinspect-buffer-parse buffer 'no-interrupt))))))

(defun phpinspect-fix-imports ()
  "Find types that are used in the current buffer and make sure
that there are import (\"use\") statements for them."
  (interactive)
  (if phpinspect-current-buffer
      (let* ((buffer phpinspect-current-buffer)
             ;; use buffer-reparse to ensure fully structurally correct
             ;; tree. (at the time of writing, incremental parsing has some
             ;; limitations causing reused tokens to lose their special meaning
             ;; when they are reused. For example the "class" keyword being
             ;; reused as just a word instead of a special keyword marking the
             ;; start of a class)
             ;;
             ;; FIXME: Change to buffer-parse when this particular problem in
             ;; incremental parsing has been solved
             (tree (phpinspect-buffer-reparse-if-not-fresh buffer))
             (index (phpinspect--index-tokens
                     tree nil (phpinspect-buffer-location-resolver buffer)))
             (classes (alist-get 'classes index))
             (imports (alist-get 'imports index))
             (project (phpinspect--cache-get-project-create
                       (phpinspect--get-or-create-global-cache)
                       (phpinspect-current-project-root)))
             (used-types (alist-get 'used-types index)))

        (phpinspect-add-use-statements-for-missing-types
         used-types buffer imports project (phpinspect-buffer-root-meta buffer))

        (phpinspect-remove-unneeded-use-statements
         used-types buffer imports (phpinspect-buffer-root-meta buffer))

        (dolist (class classes)
          (let* ((class-imports (alist-get 'imports class))
                 (used-types (alist-get 'used-types class))
                 (class-name (alist-get 'class-name class))
                 (region (alist-get 'location class))
                 token-meta)
            (setq token-meta (phpinspect-meta-find-parent-matching-token
                              (phpinspect-bmap-last-token-before-point
                               (phpinspect-buffer-map buffer)
                               (+ (phpinspect-region-start region) 1))
                              #'phpinspect-class-p))
            (unless token-meta
              (error "Unable to find token for class %s" class-name))

            (phpinspect-add-use-statements-for-missing-types
             used-types buffer (append imports class-imports) project token-meta)

            (phpinspect-remove-unneeded-use-statements
             used-types buffer class-imports token-meta))))))

(provide 'phpinspect-imports)
