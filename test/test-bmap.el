
(require 'phpinspect-bmap)

(ert-deftest phpinspect-bmap-overlay ()
  (let ((bmap (phpinspect-make-bmap))
        (bmap2 (phpinspect-make-bmap))
        (bmap3 (phpinspect-make-bmap)))

    (phpinspect-bmap-register bmap 10 20 'token)
    (phpinspect-bmap-register bmap2 20 24 'token2)
    (phpinspect-bmap-register bmap3 40 50 'token3)

    (should (phpinspect-bmap-token-starting-at bmap 10))

    (phpinspect-bmap-overlay
     bmap bmap3 (phpinspect-bmap-token-starting-at bmap3 40) 10)

    (should (phpinspect-bmap-token-starting-at bmap 50))

    (phpinspect-bmap-overlay
     bmap2 bmap (phpinspect-bmap-token-starting-at bmap 10) -3)

    (phpinspect-bmap-overlay
     bmap2 bmap (phpinspect-bmap-token-starting-at bmap 50) 5)


    (should (eq 'token2 (phpinspect-meta-token
                         (phpinspect-bmap-token-starting-at bmap2 20))))
    (should (eq 'token (phpinspect-meta-token
                        (phpinspect-bmap-token-starting-at bmap2 7))))

    ;; Nesting for token-starting-at
    (should (eq 'token3 (phpinspect-meta-token
                         (phpinspect-bmap-token-starting-at bmap 50))))

    (should (eq 'token3 (phpinspect-meta-token
                         (phpinspect-bmap-token-starting-at bmap2 55))))


    (should (phpinspect-bmap-token-meta bmap 'token))
    (should (phpinspect-bmap-token-meta bmap2 'token2))
    (should (phpinspect-bmap-token-meta bmap2 'token))
    (should (phpinspect-bmap-token-meta bmap2 'token3))))

(ert-deftest phpinspect-bmap-nest-parent ()
  (let ((bmap (phpinspect-make-bmap)))
    (phpinspect-bmap-register bmap 10 20 'child)
    (phpinspect-bmap-register bmap 5 25 'parent)
    (phpinspect-bmap-register bmap 2 30 'granny)

    (let ((child (phpinspect-bmap-token-meta bmap 'child))
          (parent (phpinspect-bmap-token-meta bmap 'parent)))
      (should (eq 'parent (phpinspect-meta-token
                           (phpinspect-meta-parent child))))
      (should (eq 'granny (phpinspect-meta-token (phpinspect-meta-parent parent)))))))


(ert-deftest phpinspect-bmap-tokens-overlapping ()
  (let ((bmap (phpinspect-make-bmap)))
    (phpinspect-bmap-register bmap 9 200 'node1)
    (phpinspect-bmap-register bmap 20  200 'node2)
    (phpinspect-bmap-register bmap 9  20 'node3)
    (phpinspect-bmap-register bmap 21  44 'node4)

    (setq result (phpinspect-bmap-tokens-overlapping bmap 22))
    (should (equal '(node4 node2 node1) (mapcar #'phpinspect-meta-token result)))))

(ert-deftest phpinspect-bmap-tokens-overlapping-overlayed ()
  (let ((bmap (phpinspect-make-bmap))
        (bmap2 (phpinspect-make-bmap))
        (bmap3 (phpinspect-make-bmap)))
    (phpinspect-bmap-register bmap 9 200 'token1)
    (phpinspect-bmap-register bmap 20 200 'token2)
    (phpinspect-bmap-register bmap 9 20 'token3)
    (phpinspect-bmap-register bmap 21 44 'token4)

    (phpinspect-bmap-register bmap2 200 230 'token5)
    (phpinspect-bmap-register bmap3 300 305 'token6)

    ;; Should start at 220 of bmap2
    (phpinspect-bmap-overlay
     bmap2 bmap3 (phpinspect-bmap-token-starting-at bmap3 300) -80)

    (setq result (phpinspect-bmap-tokens-overlapping bmap2 220))
    (should (equal '(token6 token5) (mapcar #'phpinspect-meta-token result)))

    (phpinspect-bmap-overlay
     bmap bmap2 (phpinspect-bmap-token-starting-at bmap2 200) 20)

    (setq result (phpinspect-bmap-tokens-overlapping bmap 240))
    (should (equal '(token6 token5) (mapcar #'phpinspect-meta-token result)))

    (setq result (phpinspect-bmap-tokens-overlapping bmap 22))
    (should (equal '(token4 token2 token1) (mapcar #'phpinspect-meta-token result)))))

(ert-deftest phpinspect-bmap-register ()
  (let* ((bmap (phpinspect-make-bmap))
         (token1 `(:word "foo"))
         (token2 `(:word "bar"))
         (token3 `(:block ,token1 ,token2))
         (token4 `(:list ,token3)))
    (phpinspect-bmap-register bmap 10 20 token1)
    (phpinspect-bmap-register bmap 20 30 token2)
    (phpinspect-bmap-register bmap 9 31 token3)
    (phpinspect-bmap-register bmap 8 32 token4)

    (should (phpinspect-bmap-token-meta bmap token1))
    (should (phpinspect-bmap-token-meta bmap token2))
    (should (phpinspect-bmap-token-meta bmap token3))
    (should (phpinspect-bmap-token-meta bmap token4))))
