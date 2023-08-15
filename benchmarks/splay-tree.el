;;; splay-tree.el --- Benchmarks of phpinspect-splayt.el  -*- lexical-binding: t; -*-

;; Copyright (C) 2023  Free Software Foundation, Inc

;; Author: Hugo Thunnissen <devel@hugot.nl>
;; Keywords: benchmark

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

;;; Code:


(require 'phpinspect-splayt)

(let ((here (file-name-directory (or load-file-name buffer-file-name)))
      (tree (phpinspect-make-splayt)))
  (message "Splay tree 10000 insertions:")
  (garbage-collect)
  (benchmark
   1 '(dotimes (i 10000)
        (phpinspect-splayt-insert tree i 'value)))

  (message "Splay tree 10000 lookups:")
  (garbage-collect)
  (benchmark
   1 '(dotimes (i 10000)
        (phpinspect-splayt-find tree i)))

  (message "Splay tree 10000 items traversal:")
  (garbage-collect)
  (benchmark
   1 '(phpinspect-splayt-traverse (i tree)
        nil))

  (message "Splay tree 10000 items LR traversal:")
  (garbage-collect)
  (benchmark
   1 '(phpinspect-splayt-traverse-lr (i tree)
        nil)))


(let (map)
  (message "Hashtable 10000 insertions:")
  (garbage-collect)
  (benchmark
   1 '(progn
        (setq map (make-hash-table :test #'eq :size 10000 :rehash-size 1.5))
        (dotimes (i 10000)
        (puthash i 'value map))))

  (message "Hashtable 10000 lookups:")
  (garbage-collect)
  (benchmark
   1 '(dotimes (i 10000)
        (gethash i map)))

  (message "Hashtable 10000 iterations:")
  (garbage-collect)
  (benchmark
   1 '(maphash (lambda (k v) nil) map)))
