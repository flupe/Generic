module Generic.Lib.Decidable where

open import Relation.Nullary public
open import Relation.Nullary.Decidable hiding (map) public
open import Relation.Binary using (Decidable) public

open import Generic.Lib.Intro
open import Generic.Lib.Equality.Propositional
open import Generic.Lib.Equality.Heteroindexed
open import Generic.Lib.Data.Sum
open import Generic.Lib.Data.Product

open import Relation.Nullary
import Data.String as String

infix 3 _#_

IsSet : ∀ {α} -> Set α -> Set α
IsSet A = Decidable {A = A} _≡_

record Eq {α} (A : Set α) : Set α where
  infixl 5 _≟_ _==_

  field _≟_ : IsSet A

  _==_ : A -> A -> Bool
  x == y = ⌊ x ≟ y ⌋ 
open Eq {{...}} public

record _↦_ {α} (A B : Set α) : Set α where
  constructor packInj
  field
    to      : A -> B
    from    : B -> A
    from-to : from ∘ to ≗ id

-- Can't make it an instance, because otherwise it unreasonably breaks instance search.
viaInj : ∀ {α} {A B : Set α} {{bEq : Eq B}} -> A ↦ B -> Eq A
viaInj {A = A} {B} inj = record
  { _≟_ = flip (via-injection {A = ≡-Setoid A} {B = ≡-Setoid B}) _≟_ $ record
      { to        = record
          { _⟨$⟩_ = to
          ; cong  = cong to
          }
      ; injective = λ q -> right (from-to _) (trans (cong from q) (from-to _))
      }
  } where open _↦_ inj

_#_ : ∀ {α} {A : Set α} -> A -> A -> Set
x # y = Dec (x ≡ y)

delim : ∀ {α π} {A : Set α} {P : Dec A -> Set π}
      -> (∀ x -> P (yes x)) -> (∀ c -> P (no c)) -> (d : Dec A) -> P d
delim f g (yes x) = f x
delim f g (no  c) = g c

drec : ∀ {α β} {A : Set α} {B : Set β} -> (A -> B) -> (¬ A -> B) -> Dec A -> B
drec = delim

dmap : ∀ {α β} {A : Set α} {B : Set β} -> (A -> B) -> (¬ A -> ¬ B) -> Dec A -> Dec B
dmap f g = drec (yes ∘ f) (no ∘ g)

sumM2 : ∀ {α β γ} {A : Set α} {B : Set β} {C : Set γ}
      -> (A -> Dec C) -> (B -> Dec C) -> (¬ A -> ¬ B -> Dec C) -> Dec A -> Dec B -> Dec C
sumM2 f g h d e = drec f (λ c -> drec g (h c) e) d

prodM2 : ∀ {α β γ} {A : Set α} {B : Set β} {C : Set γ}
       -> (A -> B -> Dec C) -> (¬ A -> Dec C) -> (¬ B -> Dec C) -> Dec A -> Dec B -> Dec C
prodM2 h f g d e = drec (λ x -> drec (h x) g e) f d

sumF2 : ∀ {α β γ} {A : Set α} {B : Set β} {C : Set γ}
      -> (A -> C) -> (B -> C) -> (¬ A -> ¬ B -> ¬ C) -> Dec A -> Dec B -> Dec C
sumF2 f g h = sumM2 (yes ∘ f) (yes ∘ g) (no % ∘ h) 

prodF2 : ∀ {α β γ} {A : Set α} {B : Set β} {C : Set γ}
       -> (A -> B -> C) -> (¬ A -> ¬ C) -> (¬ B -> ¬ C) -> Dec A -> Dec B -> Dec C
prodF2 h f g = prodM2 (yes % ∘ h) (no ∘ f) (no ∘ g) 

dcong : ∀ {α β} {A : Set α} {B : Set β} {x y}
      -> (f : A -> B) -> (f x ≡ f y -> x ≡ y) -> x # y -> f x # f y
dcong f inj = dmap (cong f) (_∘ inj)

dcong₂ : ∀ {α β γ} {A : Set α} {B : Set β} {C : Set γ} {x₁ x₂ y₁ y₂}
       -> (f : A -> B -> C)
       -> (f x₁ y₁ ≡ f x₂ y₂ -> x₁ ≡ x₂ × y₁ ≡ y₂)
       -> x₁ # x₂
       -> y₁ # y₂
       -> f x₁ y₁ # f x₂ y₂
dcong₂ f inj = prodF2 (cong₂ f) (λ c -> c ∘ proj₁ ∘ inj) (λ c -> c ∘ proj₂ ∘ inj)

dhcong₂ : ∀ {α β γ} {A : Set α} {B : A -> Set β} {C : Set γ} {x₁ x₂ y₁ y₂}
        -> (f : ∀ x -> B x -> C) 
        -> (f x₁ y₁ ≡ f x₂ y₂ -> [ B ] y₁ ≅ y₂)
        -> x₁ # x₂
        -> (∀ y₂ -> y₁ # y₂)
        -> f x₁ y₁ # f x₂ y₂
dhcong₂ f inj (yes refl) q = dcong (f _) (homo ∘ inj) (q _)
dhcong₂ f inj (no  c)    q = no (c ∘ inds ∘ inj)

dsubst : ∀ {α β γ} {A : Set α} {x y}
       -> (B : A -> Set β)
       -> (C : ∀ {x} -> B x -> Set γ)
       -> x # y
       -> (z : B x)
       -> ((z : B y) -> C z)
       -> (x ≢ y -> C z)
       -> C z
dsubst B C (yes refl) z g h = g z
dsubst B C (no  c)    z g h = h c

dsubst′ : ∀ {α β γ} {A : Set α} {C : Set γ} {x y}
        -> (B : A -> Set β) -> x # y -> B x -> (B y -> C) -> (x ≢ y -> C) -> C
dsubst′ B = dsubst B _

,-inj : ∀ {α β} {A : Set α} {B : A -> Set β} {x₁ x₂} {y₁ : B x₁} {y₂ : B x₂}
      -> (x₁ , y₁) ≡ (x₂ , y₂) -> [ B ] y₁ ≅ y₂
,-inj refl = irefl

inj₁-inj : ∀ {α β} {A : Set α} {B : Set β} {x₁ x₂ : A}
         -> inj₁ {B = B} x₁ ≡ inj₁ x₂ -> x₁ ≡ x₂
inj₁-inj refl = refl

inj₂-inj : ∀ {α β} {A : Set α} {B : Set β} {y₁ y₂ : B}
         -> inj₂ {A = A} y₁ ≡ inj₂ y₂ -> y₁ ≡ y₂
inj₂-inj refl = refl

-- _<,>ᵈ_ : ∀ {α β} {A : Set α} {B : Set β} {x₁ x₂ : A} {y₁ y₂ : B}
--        -> x₁ # x₂ -> y₁ # y₂ -> x₁ , y₁ # x₂ , y₂
-- _<,>ᵈ_ = dcong₂ _,_ (inds-homo ∘ ,-inj)

-- _<,>ᵈᵒ_ : ∀ {α β} {A : Set α} {B : A -> Set β} {x₁ x₂} {y₁ : B x₁} {y₂ : B x₂}
--         -> x₁ # x₂ -> (∀ y₂ -> y₁ # y₂) -> x₁ , y₁ # x₂ , y₂
-- _<,>ᵈᵒ_ = dhcong₂ _,_ ,-inj

decSum : ∀ {α β} {A : Set α} {B : Set β}
       -> IsSet A -> IsSet B -> IsSet (A ⊎ B)
decSum f g (inj₁ x₁) (inj₁ x₂) = dcong inj₁ inj₁-inj (f x₁ x₂)
decSum f g (inj₂ y₁) (inj₂ y₂) = dcong inj₂ inj₂-inj (g y₁ y₂)
decSum f g (inj₁ x₁) (inj₂ y₂) = no λ()
decSum f g (inj₂ y₁) (inj₁ x₂) = no λ()

decProd : ∀ {α β} {A : Set α} {B : A -> Set β}
        -> IsSet A -> (∀ {x} -> IsSet (B x)) -> IsSet (Σ A B)
decProd f g (x₁ , y₁) (x₂ , y₂) = dhcong₂ _,_ ,-inj (f x₁ x₂) (g y₁)

module _ where
  import Relation.Binary.PropositionalEquality as B

  liftBase : ∀ {α} {A : Set α} {x y : A} -> x B.≡ y -> x ≡ y
  liftBase B.refl = refl

  lowerBase : ∀ {α} {A : Set α} {x y : A} -> x ≡ y -> x B.≡ y
  lowerBase refl = B.refl

  viaBase : ∀ {α} {A : Set α} -> Decidable (B._≡_ {A = A}) -> Eq A
  viaBase d = record
    { _≟_ = flip (via-injection {A = ≡-Setoid _} {B = B.setoid _}) d $ record
        { to = record
            { _⟨$⟩_ = id
            ; cong  = lowerBase
            }
        ; injective = liftBase
        }
    }
