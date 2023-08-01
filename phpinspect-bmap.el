;;; phpinspect-bmap.el --- PHP parsing and completion package  -*- lexical-binding: t; -*-

;; Copyright (C) 2021  Free Software Foundation, Inc

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

;;; Code:

(require 'phpinspect-splayt)
(require 'phpinspect-meta)
(require 'phpinspect-util)
(require 'compat)

(cl-defstruct (phpinspect-bmap (:constructor phpinspect-make-bmap))
  (starts (make-hash-table :test #'eql
                           :size (floor (/ (point-max) 4))
                           :rehash-size 1.5))
  (ends (make-hash-table :test #'eql
                           :size (floor (/ (point-max) 4))
                           :rehash-size 1.5))
  (meta (make-hash-table :test #'eq
                           :size (floor (/ (point-max) 4))
                           :rehash-size 1.5))
  (token-stack nil
               :type list)
  (overlays (phpinspect-make-splayt)
            :type phpinspect-splayt)
  (-root-meta nil
              :type phpinspect-meta)
  (last-token-start nil
                    :type integer))

(define-inline phpinspect-bmap-root-meta (bmap)
  (inline-letevals (bmap)
    (inline-quote
     (with-memoization (phpinspect-bmap--root-meta ,bmap)
       (phpinspect-bmap-token-starting-at
        ,bmap (phpinspect-bmap-last-token-start ,bmap))))))

(defsubst phpinspect-make-region (start end)
  (list start end))

(defalias 'phpinspect-region-start #'car)
(defalias 'phpinspect-region-end #'cadr)

(defsubst phpinspect-region-size (region)
  (- (phpinspect-region-end region) (phpinspect-region-start region)))

(defsubst phpinspect-region> (reg1 reg2)
  (> (phpinspect-region-size reg1) (phpinspect-region-size reg2)))

(defsubst phpinspect-region< (reg1 reg2)
  (< (phpinspect-region-size reg1) (phpinspect-region-size reg2)))

(defsubst phpinspect-region-overlaps-point (reg point)
  (and (> (phpinspect-region-end reg) point)
       (<= (phpinspect-region-start reg) point)))

(defsubst phpinspect-region-overlaps (reg1 reg2)
  (or (phpinspect-region-overlaps-point reg1 (phpinspect-region-start reg2))
      (phpinspect-region-overlaps-point reg1 (- (phpinspect-region-end reg2) 1))
      (phpinspect-region-overlaps-point reg2 (phpinspect-region-start reg1))
      (phpinspect-region-overlaps-point reg2 (- (phpinspect-region-end reg1) 1))))

(defsubst phpinspect-region-encloses (reg1 reg2)
  (and (<= (phpinspect-region-start reg1) (phpinspect-region-start reg2))
       (>= (phpinspect-region-end reg1) (phpinspect-region-end reg2))))

(define-inline phpinspect-overlay-bmap (overlay)
  (inline-quote (car (nthcdr 4 ,overlay))))

(define-inline phpinspect-overlay-delta (overlay)
  (inline-quote (cadddr ,overlay)))

(define-inline phpinspect-overlay-start (overlay)
  (inline-quote (cadr ,overlay)))

(define-inline phpinspect-overlay-end (overlay)
  (inline-quote (caddr ,overlay)))

(define-inline phpinspect-overlay-overlaps-point (overlay point)
  (inline-letevals (overlay point)
    (inline-quote
     (and (> (phpinspect-overlay-end ,overlay) ,point)
          (<= (phpinspect-overlay-start ,overlay) ,point)))))

(defmacro phpinspect-bmap-iterate-region (region place-and-bmap &rest body)
  (declare (indent defun))
  (let ((place (car place-and-bmap))
        (bmap (gensym))
        (bmap-stack (gensym))
        (region-start (gensym))
        (region-end (gensym)))
    `(let ((,bmap)
           ,(when (symbolp place) place)
           (,bmap-stack (list ,(cadr place-and-bmap)))
           (,region-start (car ,region))
           (,region-end (cadr ,region)))
       (while (setq ,bmap (pop ,bmap-stack))
         (phpinspect-bmap-iterate (,place ,bmap)
           (when (and (<= ,region-start
                          (phpinspect-meta-start ,place))
                      (>= ,region-end
                          (phpinspect-meta-end ,place)))
             ,@body))))))

(defmacro phpinspect-bmap-iterate (place-and-bmap &rest body)
  (declare (indent defun))
  (let ((place (car place-and-bmap))
        (bmap (gensym))
        (_ignored (gensym)))
    `(let ((,bmap ,(cadr place-and-bmap)))
       (maphash (lambda (,_ignored ,place)
                  ,@body
                  (when (phpinspect-meta-overlay ,place)
                    (phpinspect-splayt-traverse (,place (phpinspect-meta-children ,place))
                      ,@body)))
                (phpinspect-bmap-meta ,bmap)))))

(defsubst phpinspect-bmap-register (bmap start end token &optional whitespace-before overlay)
  (let* ((starts (phpinspect-bmap-starts bmap))
         (ends (phpinspect-bmap-ends bmap))
         (meta (phpinspect-bmap-meta bmap))
         (last-token-start (phpinspect-bmap-last-token-start bmap))
         (existing-end (gethash end ends))
         (token-meta (or overlay (phpinspect-make-meta nil start end whitespace-before token))))
    (when (< end start)
      (error "Token %s ends before it starts. Start: %s, end: %s" token start end))

    (unless whitespace-before
      (setq whitespace-before ""))

    (puthash start token-meta starts)

    (if existing-end
        (push token existing-end)
      (puthash end (list token-meta) ends))

    (puthash token token-meta meta)

    (when (and last-token-start
               (<= start last-token-start))
      (let ((child)
            (stack (phpinspect-bmap-token-stack bmap)))
        (while (and (car stack) (>= (phpinspect-meta-start (car stack)) start))
          (setq child (pop stack))
          (phpinspect-meta-set-parent child token-meta))

          (setf (phpinspect-bmap-token-stack bmap) stack)))

    (setf (phpinspect-bmap-last-token-start bmap) start)
    (push token-meta (phpinspect-bmap-token-stack bmap))))

(defsubst phpinspect-overlay-p (overlay)
  (and (listp overlay)
       (eq 'overlay (car overlay))))

(cl-defmethod phpinspect-bmap-token-starting-at ((overlay (head overlay)) point)
  (phpinspect-bmap-token-starting-at
   (phpinspect-overlay-bmap overlay) (- point (phpinspect-overlay-delta overlay))))

(cl-defmethod phpinspect-bmap-token-starting-at ((bmap phpinspect-bmap) point)
  (let ((overlay (phpinspect-bmap-overlay-at-point bmap point)))
    (if overlay
          (phpinspect-bmap-token-starting-at overlay point)
      (gethash point (phpinspect-bmap-starts bmap)))))

(cl-defmethod phpinspect-bmap-tokens-ending-at ((overlay (head overlay)) point)
  (phpinspect-bmap-tokens-ending-at
   (phpinspect-overlay-bmap overlay) (- point (phpinspect-overlay-delta overlay))))

(cl-defmethod phpinspect-bmap-tokens-ending-at ((bmap phpinspect-bmap) point)
  (let ((overlay (phpinspect-bmap-overlay-at-point bmap point)))
    (if overlay
        (phpinspect-bmap-tokens-ending-at overlay point)
      (gethash point (phpinspect-bmap-ends bmap)))))

(defsubst phpinspect-bmap-overlay-at-point (bmap point)
  (let ((overlay (phpinspect-splayt-find-largest-before (phpinspect-bmap-overlays bmap) point)))
    (when (and overlay (phpinspect-overlay-overlaps-point overlay point))
      overlay)))

(defsubst phpinspect-bmap-tokens-overlapping (bmap point)
  (let ((tokens))
    (phpinspect-bmap-iterate (meta bmap)
      (when (phpinspect-meta-overlaps-point meta point)
        (push meta tokens)))

    (sort tokens #'phpinspect-meta-sort-width)))

(defsubst phpinspect-overlay-encloses-meta (overlay meta)
  (and (>= (phpinspect-meta-start meta) (phpinspect-overlay-start overlay))
       (<= (phpinspect-meta-end meta) (phpinspect-overlay-end overlay))))

(cl-defmethod phpinspect-bmap-token-meta ((overlay (head overlay)) token)
  (phpinspect-bmap-token-meta (phpinspect-overlay-bmap overlay) token))

(cl-defmethod phpinspect-bmap-token-meta ((bmap phpinspect-bmap) token)
  (unless (phpinspect-probably-token-p token)
    (error "Unexpected argument, expected `phpinspect-token-p'. Got invalid token %s" token))

  (or (gethash token (phpinspect-bmap-meta bmap))
      (let ((found?))
        (catch 'found
          (phpinspect-splayt-traverse (overlay (phpinspect-bmap-overlays bmap))
            (when (setq found? (phpinspect-bmap-token-meta overlay token))
              ;; Hit overlay's node to rebalance tree
              (phpinspect-splayt-find
               (phpinspect-bmap-overlays bmap) (phpinspect-overlay-end overlay))
              (throw 'found found?)))))))

(defsubst phpinspect-probably-token-p (token)
  (and (listp token)
       (keywordp (car token))))

(cl-defmethod phpinspect-bmap-last-token-before-point ((bmap phpinspect-bmap) point)
  "Search backward in BMAP for last token ending before POINT."
  (phpinspect-meta-find-child-before-recursively (phpinspect-bmap-root-meta bmap) point))

(defsubst phpinspect-bmap-overlay (bmap bmap-overlay token-meta pos-delta &optional whitespace-before)
  (let* ((overlays (phpinspect-bmap-overlays bmap))
         (start (+ (phpinspect-meta-start token-meta) pos-delta))
         (end (+ (phpinspect-meta-end token-meta) pos-delta))
         (overlay)
         (last-overlay (phpinspect-splayt-node-value (phpinspect-splayt-root-node overlays))))

    (phpinspect-meta-with-changeset token-meta
      (phpinspect-meta-detach-parent token-meta)
      (phpinspect-meta-shift token-meta pos-delta)

      (if (and last-overlay (= (- start (length whitespace-before)) (phpinspect-overlay-end last-overlay))
               (= pos-delta (phpinspect-overlay-delta last-overlay)))
          (progn
            (phpinspect--log "Expanding previous overlay from (%d,%d) to (%d,%d)"
                             (phpinspect-overlay-start last-overlay) (phpinspect-overlay-end last-overlay)
                             (phpinspect-overlay-start last-overlay) end)
            (setf (phpinspect-overlay-end last-overlay) end)
            (setf (phpinspect-meta-overlay token-meta) last-overlay))
        (phpinspect--log "Inserting new overlay at (%d,%d)" start end)
        (setq overlay `(overlay ,start ,end ,pos-delta ,bmap-overlay ,token-meta))
        (setf (phpinspect-meta-overlay token-meta) overlay)
        (phpinspect-splayt-insert (phpinspect-bmap-overlays bmap) (phpinspect-overlay-start overlay) overlay))
      (phpinspect-bmap-register bmap start end (phpinspect-meta-token token-meta) whitespace-before token-meta))))

(defun phpinspect-bmap-make-location-resolver (bmap)
  (lambda (token)
    (let ((meta (phpinspect-bmap-token-meta bmap token)))
      (if meta
          (phpinspect-make-region (phpinspect-meta-start meta)
                                  (phpinspect-meta-end meta))
        (phpinspect-make-region 0 0)))))

(provide 'phpinspect-bmap)
;;; phpinspect-bmap.el ends here
