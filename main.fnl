(local fennel (require :fennel))

(fn p [x]
  (print (fennel.view x))
  x)

(lambda shallow-copy [t]
  (collect [k v (pairs t)] k v))

(macro with-copy [[copy original] ...]
  `(let [,copy (shallow-copy ,original)]
     ,...
     ,copy))

(macro def-copying [name f]
  `(local ,name (lambda [t# ...]
                  (with-copy [u# t#]
                     (,f u# ...)))))

(def-copying sorted table.sort)
(def-copying inserted table.insert)

(lambda merged [?t u]
  (if ?t
    (with-copy [t1 ?t]
      (each [k v (pairs u)]
        (tset t1 k v)))
    (shallow-copy u)))

(lambda update [?t k f]
  (merged ?t {k (f (if ?t (. ?t k) nil))}))

(lambda empty? [seq]
  (= 0 (length seq)))

(lambda drop [seq n]
  (var result [])
  (for [i (+ n 1) (length seq)]
    (table.insert result (. seq i)))
  result)

(lambda take [seq n]
  (var result [])
  (for [i 1 (math.min (length seq) n)]
    (table.insert result (. seq i)))
  result)

(lambda drop-last [seq n]
  (take seq (- (length seq) n)))

(lambda update-in [?t ks f]
  (if (empty? ks)
    (f ?t)
    (update ?t (. ks 1) (lambda [?t]
                         (update-in ?t (drop ks 1) f)))))

(lambda keys [t]
  (icollect [k v (pairs t)] k))

(lambda sum [xs]
  (accumulate [result 0
               _ x (ipairs xs)]
    (+ result x)))

(lambda pairs/sorted [t]
  (local sorted-keys (sorted (keys t)))
  (var i 1)
  (lambda []
    (if (> i (length sorted-keys))
      nil
      (do
        (let [j i]
          (set i (+ i 1))
          (values (. sorted-keys j)
                  (. t (. sorted-keys j))))))))

(lambda map [f seq]
  (icollect [k v (ipairs seq)]
    (f v k)))

(lambda vals [t]
  (icollect [k v (pairs t)] v))

;;

(lambda resolve [ps u]
  (-> (accumulate [[r s] [nil 0]
                    k v (pairs/sorted ps)]
        (if (>= (+ s v) u)
          (if (= nil r)
            [k (+ s v)]
            [r (+ s v)])
          [nil (+ s v)]))
      (. 1)))

(lambda total-observations-for [obs-a]
  (sum (vals obs-a)))

(lambda total-observations [obs]
  (sum (map total-observations-for obs)))

(lambda probabilities [obs]
  (collect [k v (pairs obs)]
     k (/ v (total-observations-for obs))))

(lambda register-observation [obs s x]
  (update-in obs [s x] #(+ 1 (or $1 0))))

(lambda register-observations [obs xs]
  (-> (accumulate [[obs s] [obs :.]
                   _ x (ipairs (inserted xs :.))]
        [(register-observation obs s x) x])
      (. 1)))

(lambda chars [s]
  (local result [])
  (for [i 1 (length s)]
    (table.insert result (s:sub i i)))
  result)

(lambda register-word [obs word]
  (register-observations obs (chars word)))

(lambda split-words [s]
  (-> (accumulate [[words buffer] [[] ""]
                   _ c (ipairs (chars s))]
        (if (= " " c)
          [(if (not (= "" buffer))
              (inserted words buffer)
              buffer)
           ""]
          [words (.. buffer c)]))
      (#(inserted (. $1 1) (. $1 2)))))

(lambda join [ss]
  (var result "")
  (each [_ c (ipairs ss)]
    (set result (.. result c)))
  result)

(lambda register-words [obs s]
  (accumulate [obs {}
               _ word (ipairs (split-words s))]
    (register-word obs word)))

(lambda step [obs previous outcome]
  (resolve (probabilities (. obs previous)) outcome))

(lambda walk [obs outcome-iterator]
  (->
    (accumulate [[result previous] [[] :.]
                 outcome (outcome-iterator)
                 :until (and (= previous :.)
                             (not (empty? result)))]
      (let [current (step obs previous outcome)]
        [(inserted result current) current]))
    (. 1)
    (drop-last 1)))

(lambda walk-string [input outcome-iterator]
  (join (walk (register-words {} input) outcome-iterator)))

(lambda randoms []
  (math.randomseed (os.time))
  (lambda []
    (math.random)))

(local words (io.read :*a))
(p (walk-string words randoms))

