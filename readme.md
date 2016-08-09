# Generic

It's a library for doing generic programming in Agda.

# A quick taste

Deriving decidable equality for vectors:

```
open import Data.Vec using (Vec) renaming ([] to []ᵥ; _∷_ to _∷ᵥ_)

instance VecEq : ∀ {n α} {A : Set α} {{aEq : Eq A}} -> Eq (Vec A n)
unquoteDef VecEq = deriveEqTo VecEq (quote Vec)

xs : Vec ℕ 3
xs = 2 ∷ᵥ 4 ∷ᵥ 1 ∷ᵥ []ᵥ

test₁ : xs ≟ xs ≡ yes refl
test₁ = refl

test₂ : xs ≟ (2 ∷ᵥ 4 ∷ᵥ 2 ∷ᵥ []ᵥ) ≡ no _
test₂ = refl
```

Same for `Data.Star`:

```
open import Data.Star

instance StarEq : ∀ {i t} {I : Set i} {T : Rel I t} {i j}
                    {{iEq : Eq I}} {{tEq : ∀ {i j} -> Eq (T i j)}} -> Eq (Star T i j)
unquoteDef StarEq = deriveEqTo StarEq (quote Star)
```

(For this to type check you need the recent development version of Agda (as of 09.08.16))

# Internally

Descriptions of constructors are defined as follows:

```
mutual
  Binder : ∀ {ι} α β γ -> ι ⊔ lsuc (α ⊔ β) ≡ γ -> Set ι -> Set γ
  Binder α β γ q I = Coerce q (∃ λ (A : Set α) -> A -> Desc I β)

  data Desc {ι} (I : Set ι) β : Set (ι ⊔ lsuc β) where
    var : I -> Desc I β
    π   : ∀ {α}
        -> (q : α ≤ℓ β) -> Visibility -> Binder α β _ (cong (λ αβ -> ι ⊔ lsuc αβ) q) I -> Desc I β
    _⊛_ : Desc I β -> Desc I β -> Desc I β
```

Constructors are interpreted in the way described in [Descriptions](http://effectfully.blogspot.com/2016/04/descriptions.html) (in the `CompProp` module). That `Coerce` stuff is elaborated in [Emulating cumulativity in Agda](http://effectfully.blogspot.com/2016/07/cumu.html).

A description of a data type is a list of named constructors

```
record Data {α} (A : Set α) : Set α where
  no-eta-equality
  constructor packData
  field
    dataName  : Name
    parsTele  : Type
    indsTele  : Type
    consTypes : List A
    consNames : All (const Name) consTypes
```

For regular data types `A` is instantiated to `Type`, for described data types `A` is instantiated to `Desc I β` for some `I` and `β`. Descriptions also store the name of an original data type and telescopes of types of parameters and indices. `Name` and `Type` come from the `Reflection` module.

There is a reflection machinery that allows to parse regular Agda data types into their described counterparts. An example from the [`Examples/ReadData.agda`](Examples/ReadData.agda) module:

```
data D {α β} (A : Set α) (B : ℕ -> Set β) : ∀ {n} -> B n -> List ℕ -> Set (α ⊔ β) where
  c₁ : ∀ {n} (y : B n) xs -> A -> D A B y xs
  c₂ : ∀ {y : B 0} -> (∀ {n} (y : B n) {{xs}} -> D A B y xs) -> List A -> D A B y []

D′ : ∀ {α β} (A : Set α) (B : ℕ -> Set β) {n} -> B n -> List ℕ -> Set (α ⊔ β)
D′ = readData D

pattern c₁′ {n} y xs x = #₀  (n , y , xs , x , lrefl)
pattern c₂′ {y} r ys   = !#₁ (y , r , ys , lrefl)

inj : ∀ {α β} {A : Set α} {B : ℕ -> Set β} {n xs} {y : B n} -> D A B y xs -> D′ A B y xs
inj (c₁ y xs x) = c₁′ y xs x
inj (c₂ r ys)   = c₂′ (λ y -> inj (r y)) ys

outj : ∀ {α β} {A : Set α} {B : ℕ -> Set β} {n xs} {y : B n} -> D′ A B y xs -> D A B y xs
outj (c₁′ y xs x) = c₁ y xs x
outj (c₂′ r ys)   = c₂ (λ y -> outj (r y)) ys
```

So universe polymorphism is fully supported, as well as implicit and instance arguments, multiple (including single or none) parameters and indices, higher-order inductive occurrences and you can define functions over described data types just like over the actual ones (though, [pattern synonyms are not equal in power to proper constructors](https://github.com/agda/agda/issues/2069)).

There is a generic procedure that allows to coerce elements of described data type to elements of the corresponding regular data types, e.g. `outj` can be defined as

```
outj : ∀ {α β} {A : Set α} {B : ℕ -> Set β} {n xs} {y : B n} -> D′ A B y xs -> D A B y xs
outj d = guncoerce d
```

Internally it's a bit of reflection sugar on top of a generic fold defined on described data types (the [`Function/FoldMono.agda`](Function/FoldMono.agda) module).

It's possible to coerce the other way around:

```
unquoteDecl foldD = deriveFoldTo foldD (quote D)

inj : ∀ {α β} {A : Set α} {B : ℕ -> Set β} {n xs} {y : B n} -> D A B y xs -> D′ A B y xs
inj = gcoerce foldD
```

`foldD` is a derived (via reflection) indexed fold (like `foldr` on `Vec`) on `D`. The procedure that derives indexed folds for regular data types is in the [`Lib/Reflection/Fold.agda`](Lib/Reflection/Fold.agda) module.

`D′` computes to the following term:

```
λ {α} {β} A B {n} z z₁ →
  μ
  (packData
  -- dataName
  (quote D)
  -- paramsType
   (rpi (iarg (def (quote Level) []))
    (abs "α"
     (rpi (iarg (def (quote Level) []))
      (abs "β"
       (rpi (earg (sort (set (rvar 1 []))))
        (abs "A"
         (rpi
          (earg
           (rpi (earg (def (quote ℕ) [])) (abs "_" (sort (set (rvar 2 []))))))
          (abs "B" unknown))))))))
  -- indicesType
   (rpi (iarg (def (quote ℕ) []))
    (abs "n"
     (rpi (earg (rvar 1 (earg (rvar 0 []) ∷ [])))
      (abs "_"
       (rpi
        (earg
         (def (quote List)
          (iarg (def (quote lzero) []) ∷ earg (def (quote ℕ) []) ∷ [])))
        (abs "_"
         (sort
          (set
           (def (quote _⊔_)
            (earg (rvar 5 []) ∷ earg (rvar 6 []) ∷ []))))))))))
  -- constructors 
   (ipi ℕ
    (λ n₁ →
       pi (B n₁)
       (λ y → pi (List ℕ) (λ xs → pi A (λ z₂ → var (n₁ , y , xs)))))
    ∷
    ipi (B 0)
    (λ y →
       ipi ℕ
       (λ n₁ →
          pi (B n₁) (λ y₁ → iipi (List ℕ) (λ xs → var (n₁ , y₁ , xs))))
       ⊛ pi (List A) (λ z₂ → var (0 , y , [])))
    ∷ [])
  -- consNames  
   (quote c₁ , quote c₂ , tt))
  (n , z , z₁)
```

Actual generic programming happens in the [`Property`](Property) subfolder. There is generic decidable equality defined over described data types. It can be used like this:

```
xs : Vec (List (Fin 4)) 3
xs = (fsuc fzero ∷ fzero ∷ [])
   ∷ᵥ (fsuc (fsuc fzero) ∷ [])
   ∷ᵥ (fzero ∷ fsuc (fsuc (fsuc fzero)) ∷ [])
   ∷ᵥ []ᵥ

test : xs ≟ xs ≡ yes refl
test = refl
```

Equality for desribed `Vec`s, `List`s and `Fin`s is derived automatically.

The [`Property/Reify.agda`](Property/Reify.agda) module implements coercion from described data types to `Term`s. Since stored names of described constructors are taken from actual constructors, reified elements of described data types are actually quoted elements of regular data types and hence the former can be converted to the latter (like with `guncoerce`, but deeply and accepts only canonical forms):

```
record Reify {α} (A : Set α) : Set α where
  field reify : A -> Term

  macro
    reflect : A -> Term -> TC _
    reflect = unify ∘ reify
open Reify {{...}} public

instance
  DescReify : ∀ {i β} {I : Set i} {D : Desc I β} {j}
                {{reD : All (ExtendReify ∘ proj₂) D}} -> Reify (μ D j)
  DescReify = ...

open import Generic.Examples.Data.Fin
open import Generic.Examples.Data.Vec

open import Data.Fin renaming (Fin to StdFin)
open import Data.Vec renaming (Vec to StdVec)

xs : Vec (Fin 4) 3
xs = fsuc (fsuc (fsuc fzero)) ∷ᵥ fzero ∷ᵥ fsuc fzero ∷ᵥ []ᵥ

xs′ : StdVec (StdFin 4) 3
xs′ = suc (suc (suc zero)) ∷ zero ∷ (suc zero) ∷ []

test : reflect xs ≡ xs′
test = refl
```

Having decidable equality on `B` we can derive decidable equality on `A` if there is an injection `A ↦ B`. To construct an injection we need two functions `to : A -> B`, `from : B -> A` and a proof `from-to : from ∘ to ≗ id`. `to` and `from` are `gcoerce` and `guncoerce` from the above and `from-to` is another generic function (defined via reflection again, placed in [`Reflection/DeriveEq.agda`](Reflection/DeriveEq.agda): `fromToClausesOf` generates clauses for it) which uses universe polymorphic n-ary [`cong`](https://github.com/effectfully/Generic/blob/master/Lib/Equality/Congn.agda) under the hood.

There are also generic `elim` in [`Function/Elim.agda`](Function/Elim.agda) (the idea is described in [Deriving eliminators of described data types](http://effectfully.blogspot.com/2016/06/deriving-eliminators-of-described-data.html) and `lookup` in [`Function/Lookup.agda`](Function/Lookup.agda) (broken currently).

Ornaments may or may not appear later (in the way described in [Unbiased ornaments](http://effectfully.blogspot.com/2016/07/unbiased-ornaments.html)). I don't find them very vital currently.

# Limitations

- No inductive-inductive or inductive-recursive data types. The latter [can be done](https://github.com/effectfully/random-stuff/blob/master/Desc/IRDesc.agda) at the cost of complicating the encoding.

- No irrelevance. I'll maybe try to fix this latter.

- No coinduction.

- You can't describe a non-strictly-positive data type. Yes, I think it's a limitation.

- Handling of records is not tested currently.

- No forcing of indices. [`Lift`](Examples/Data/Lift.agda) can be described, though.

- Reflection-related code begs for refactoring.