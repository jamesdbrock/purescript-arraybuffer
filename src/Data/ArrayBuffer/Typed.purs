-- | This module represents the functional bindings to JavaScript's `TypedArray` and other
-- | objects. See [MDN's spec](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/TypedArray) for details.

module Data.ArrayBuffer.Typed
  ( polyFill
  , Offset, Length, Range
  , buffer, byteOffset, byteLength, length
  , class TypedArray
  , whole, remainder, part, empty, fromArray
  , fill, set, setTyped, copyWithin
  , map, traverse, traverse_, filter
  , sort, reverse
  , elem, all, any
  , unsafeAt, hasIndex, at, (!)
  , foldlM, foldl1M, foldl, foldl1, foldrM, foldr1M, foldr, foldr1
  , find, findIndex, indexOf, lastIndexOf
  , slice, subArray
  , toString, toString', toArray
  ) where

import Prelude

import Data.ArrayBuffer.Types (ArrayView, kind ArrayViewType, ArrayBuffer, ByteOffset, ByteLength, Float64Array, Float32Array, Uint8ClampedArray, Uint32Array, Uint16Array, Uint8Array, Int32Array, Int16Array, Int8Array, Float64, Float32, Uint8Clamped, Uint32, Uint16, Uint8, Int32, Int16, Int8)
import Data.ArrayBuffer.ValueMapping (class BytesPerValue, class BinaryValue)
import Data.Function.Uncurried (Fn2, Fn3, mkFn2, runFn2, runFn3)
import Data.Maybe (Maybe(..))
import Data.Nullable (Nullable, notNull, null, toMaybe, toNullable)
import Data.Tuple (Tuple(..))
import Data.UInt (UInt)
import Effect (Effect)
import Effect.Uncurried (EffectFn1, EffectFn2, EffectFn3, EffectFn4, mkEffectFn2, mkEffectFn3, runEffectFn1, runEffectFn2, runEffectFn3, runEffectFn4)
import Effect.Unsafe (unsafePerformEffect)


-- | Lightweight polyfill for ie - see https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/TypedArray#Methods_Polyfill
foreign import polyFill :: Effect Unit

-- | `ArrayBuffer` being mapped by the typed array.
foreign import buffer :: forall a. ArrayView a -> ArrayBuffer

-- | Represents the offset of this view from the start of its `ArrayBuffer`.
foreign import byteOffset :: forall a. ArrayView a -> ByteOffset

-- | Represents the length of this typed array, in bytes.
foreign import byteLength :: forall a. ArrayView a -> ByteLength

foreign import lengthImpl :: forall a. ArrayView a -> Length

length :: forall a b. BytesPerValue a b => ArrayView a -> Int
length = lengthImpl


-- object creator implementations for each typed array

foreign import newUint8ClampedArray :: forall a. EffectFn3 a (Nullable ByteOffset) (Nullable ByteLength) Uint8ClampedArray
foreign import newUint32Array :: forall a. EffectFn3 a (Nullable ByteOffset) (Nullable ByteLength) Uint32Array
foreign import newUint16Array :: forall a. EffectFn3 a (Nullable ByteOffset) (Nullable ByteLength) Uint16Array
foreign import newUint8Array :: forall a. EffectFn3 a (Nullable ByteOffset) (Nullable ByteLength) Uint8Array
foreign import newInt32Array :: forall a. EffectFn3 a (Nullable ByteOffset) (Nullable ByteLength) Int32Array
foreign import newInt16Array :: forall a. EffectFn3 a (Nullable ByteOffset) (Nullable ByteLength) Int16Array
foreign import newInt8Array :: forall a. EffectFn3 a (Nullable ByteOffset) (Nullable ByteLength) Int8Array
foreign import newFloat32Array :: forall a. EffectFn3 a (Nullable ByteOffset) (Nullable ByteLength) Float32Array
foreign import newFloat64Array :: forall a. EffectFn3 a (Nullable ByteOffset) (Nullable ByteLength) Float64Array


-- ----

foreign import everyImpl :: forall a b. Fn2 (ArrayView a) (Fn2 b Offset Boolean) Boolean
foreign import someImpl :: forall a b. Fn2 (ArrayView a) (Fn2 b Offset Boolean) Boolean

foreign import fillImpl :: forall a b. EffectFn4 (ArrayView a) b (Nullable Offset) (Nullable Offset) Unit

foreign import mapImpl :: forall a b. EffectFn2 (ArrayView a) (EffectFn2 b Offset b) (ArrayView a)
foreign import forEachImpl :: forall a b. EffectFn2 (ArrayView a) (EffectFn2 b Offset Unit) Unit
foreign import filterImpl :: forall a b. Fn2 (ArrayView a) (Fn2 b Offset Boolean) (ArrayView a)
foreign import includesImpl :: forall a b. Fn3 (ArrayView a) b (Nullable Offset) Boolean
foreign import reduceImpl :: forall a b c. EffectFn3 (ArrayView a) (EffectFn3 c b Offset c) c c
foreign import reduce1Impl :: forall a b. EffectFn2 (ArrayView a) (EffectFn3 b b Offset b) b
foreign import reduceRightImpl :: forall a b c. EffectFn3 (ArrayView a) (EffectFn3 c b Offset c) c c
foreign import reduceRight1Impl :: forall a b. EffectFn2 (ArrayView a) (EffectFn3 b b Offset b) b
foreign import findImpl :: forall a b. Fn2 (ArrayView a) (Fn2 b Offset Boolean) (Nullable b)
foreign import findIndexImpl :: forall a b. Fn2 (ArrayView a) (Fn2 b Offset Boolean) (Nullable Offset)
foreign import indexOfImpl :: forall a b. Fn3 (ArrayView a) b (Nullable Offset) (Nullable Offset)
foreign import lastIndexOfImpl :: forall a b. Fn3 (ArrayView a) b (Nullable Offset) (Nullable Offset)


-- | Value-oriented array offset
type Offset = Int
-- | Value-oriented array length
type Length = Int

-- | Represents a range of indices, where if omitted, it represents the whole span.
-- | If only the second argument is omitted, then it represents the remainder of the span after the first index.
type Range = Maybe (Tuple Offset (Maybe Offset))


-- TODO use purescript-quotient
-- | Typeclass that associates a measured user-level type with a typed array.
-- |
-- | #### Creation
-- |
-- | - `whole`, `remainder`, and `part` are methods for building a typed array accessible interface
-- |   on top of an existing `ArrayBuffer` - Note, `part` and `remainder` may behave unintuitively -
-- |   when the operation is isomorphic to `whole`, the new TypedArray uses the same buffer as the input,
-- |   but not when the portion is a sub-array of the original buffer, a new one is made with
-- |   `Data.ArrayBuffer.ArrayBuffer.slice`.
-- | - `empty` and `fromArray` are methods for creating pure typed arrays
-- |
-- | #### Modification
-- |
-- | - `fill`, `set`, and `setTyped` are methods for assigning values from external sources
-- | - `map` and `traverse` allow you to create a new array from the existing values in another
-- | - `copyWithin` allows you to set values to the array that exist in other parts of the array
-- | - `filter` creates a new array without the values that don't pass a predicate
-- | - `reverse` modifies an existing array in-place, with all values reversed
-- | - `sort` modifies an existing array in-place, with all values sorted
-- |
-- | #### Access
-- |
-- | - `elem`, `all`, and `any` are functions for testing the contents of an array
-- | - `unsafeAt`, `hasIndex`, and `at` are used to get values from an array, with an offset
-- | - `foldr`, `foldrM`, `foldr1`, `foldr1M`, `foldl`, `foldlM`, `foldl1`, `foldl1M` all can reduce an array
-- | - `find` and `findIndex` are searching functions via a predicate
-- | - `indexOf` and `lastIndexOf` are searching functions via equality
-- | - `slice` returns a new typed array on the same array buffer content as the input
-- | - `subArray` returns a new typed array with a separate array buffer
-- | - `toString` prints to a CSV, `toString'` allows you to supply the delimiter
-- | - `toArray` returns an array of numeric values
class BinaryValue a t <= TypedArray (a :: ArrayViewType) (t :: Type) | a -> t where
  -- | View mapping the whole `ArrayBuffer`.
  whole :: ArrayBuffer -> ArrayView a
  -- | View mapping the rest of an `ArrayBuffer` after an index.
  remainder :: ArrayBuffer -> ByteOffset -> Effect (ArrayView a)
  -- | View mapping a region of the `ArrayBuffer`.
  part :: ArrayBuffer -> ByteOffset -> Length -> Effect (ArrayView a)
  -- | Creates an empty typed array, where each value is assigned 0
  empty :: Length -> ArrayView a
  -- | Creates a typed array from an input array of values, to be binary serialized
  fromArray :: Array t -> ArrayView a
  -- | Fill the array with a value
  fill :: ArrayView a -> t -> Range -> Effect Unit
  -- | Stores multiple values into the typed array
  set :: ArrayView a -> Maybe Offset -> Array t -> Effect Unit
  -- | Maps a new value over the typed array, creating a new buffer and typed array aswell.
  map :: (t -> Offset -> t) -> ArrayView a -> ArrayView a
  -- | Traverses over each value, returning a new one
  traverse :: (t -> Offset -> Effect t) -> ArrayView a -> Effect (ArrayView a)
  -- | Traverses over each value
  traverse_ :: (t -> Offset -> Effect Unit) -> ArrayView a -> Effect Unit
  -- | Test a predicate to pass on all values
  all :: (t -> Offset -> Boolean) -> ArrayView a -> Boolean
  -- | Test a predicate to pass on any value
  any :: (t -> Offset -> Boolean) -> ArrayView a -> Boolean
  -- | Returns a new typed array with all values that pass the predicate
  filter :: (t -> Offset -> Boolean) -> ArrayView a -> ArrayView a
  -- | Tests if a value is an element of the typed array
  elem :: t -> Maybe Offset -> ArrayView a -> Boolean
  -- | Fetch element at index.
  unsafeAt :: Offset -> ArrayView a -> Effect t
  -- | Folding from the left
  foldlM :: forall b. (b -> t -> Offset -> Effect b) -> b -> ArrayView a -> Effect b
  -- | Assumes the typed array is non-empty
  foldl1M :: (t -> t -> Offset -> Effect t) -> ArrayView a -> Effect t
  -- | Folding from the right
  foldrM :: forall b. (t -> b -> Offset -> Effect b) -> b -> ArrayView a -> Effect b
  -- | Assumes the typed array is non-empty
  foldr1M :: (t -> t -> Offset -> Effect t) -> ArrayView a -> Effect t
  -- | Returns the first value satisfying the predicate
  find :: (t -> Offset -> Boolean) -> ArrayView a -> Maybe t
  -- | Returns the first index of the value satisfying the predicate
  findIndex :: (t -> Offset -> Boolean) -> ArrayView a -> Maybe Offset
  -- | Returns the first index of the element, if it exists, from the left
  indexOf :: t -> Maybe Offset -> ArrayView a -> Maybe Offset
  -- | Returns the first index of the element, if it exists, from the right
  lastIndexOf :: t -> Maybe Offset -> ArrayView a -> Maybe Offset


instance typedArrayUint8Clamped :: TypedArray Uint8Clamped UInt where
  whole a = unsafePerformEffect (runEffectFn3 newUint8ClampedArray a null null)
  remainder a x = runEffectFn3 newUint8ClampedArray a (notNull x) null
  part a x y = runEffectFn3 newUint8ClampedArray a (notNull x) (notNull y)
  empty n = unsafePerformEffect (runEffectFn3 newUint8ClampedArray n null null)
  fromArray a = unsafePerformEffect (runEffectFn3 newUint8ClampedArray a null null)
  all = _all
  any = _any
  fill = _fill
  set = _set
  map = _map
  traverse = _traverse
  traverse_ = _traverse_
  filter = _filter
  elem = _elem
  unsafeAt = _unsafeAt
  foldlM = _foldlM
  foldl1M = _foldl1M
  foldrM = _foldrM
  foldr1M = _foldr1M
  find = _find
  findIndex = _findIndex
  indexOf = _indexOf
  lastIndexOf = _lastIndexOf
instance typedArrayUint32 :: TypedArray Uint32 UInt where
  whole a = unsafePerformEffect (runEffectFn3 newUint32Array a null null)
  remainder a x = runEffectFn3 newUint32Array a (notNull x) null
  part a x y = runEffectFn3 newUint32Array a (notNull x) (notNull y)
  empty n = unsafePerformEffect (runEffectFn3 newUint32Array n null null)
  fromArray a = unsafePerformEffect (runEffectFn3 newUint32Array a null null)
  all = _all
  any = _any
  fill = _fill
  set = _set
  map = _map
  traverse = _traverse
  traverse_ = _traverse_
  filter = _filter
  elem = _elem
  unsafeAt = _unsafeAt
  foldlM = _foldlM
  foldl1M = _foldl1M
  foldrM = _foldrM
  foldr1M = _foldr1M
  find = _find
  findIndex = _findIndex
  indexOf = _indexOf
  lastIndexOf = _lastIndexOf
instance typedArrayUint16 :: TypedArray Uint16 UInt where
  whole a = unsafePerformEffect (runEffectFn3 newUint16Array a null null)
  remainder a x = runEffectFn3 newUint16Array a (notNull x) null
  part a x y = runEffectFn3 newUint16Array a (notNull x) (notNull y)
  empty n = unsafePerformEffect (runEffectFn3 newUint16Array n null null)
  fromArray a = unsafePerformEffect (runEffectFn3 newUint16Array a null null)
  all = _all
  any = _any
  fill = _fill
  set = _set
  map = _map
  traverse = _traverse
  traverse_ = _traverse_
  filter = _filter
  elem = _elem
  unsafeAt = _unsafeAt
  foldlM = _foldlM
  foldl1M = _foldl1M
  foldrM = _foldrM
  foldr1M = _foldr1M
  find = _find
  findIndex = _findIndex
  indexOf = _indexOf
  lastIndexOf = _lastIndexOf
instance typedArrayUint8 :: TypedArray Uint8 UInt where
  whole a = unsafePerformEffect (runEffectFn3 newUint8Array a null null)
  remainder a x = runEffectFn3 newUint8Array a (notNull x) null
  part a x y = runEffectFn3 newUint8Array a (notNull x) (notNull y)
  empty n = unsafePerformEffect (runEffectFn3 newUint8Array n null null)
  fromArray a = unsafePerformEffect (runEffectFn3 newUint8Array a null null)
  all = _all
  any = _any
  fill = _fill
  set = _set
  map = _map
  traverse = _traverse
  traverse_ = _traverse_
  filter = _filter
  elem = _elem
  unsafeAt = _unsafeAt
  foldlM = _foldlM
  foldl1M = _foldl1M
  foldrM = _foldrM
  foldr1M = _foldr1M
  find = _find
  findIndex = _findIndex
  indexOf = _indexOf
  lastIndexOf = _lastIndexOf
instance typedArrayInt32 :: TypedArray Int32 Int where
  whole a = unsafePerformEffect (runEffectFn3 newInt32Array a null null)
  remainder a x = runEffectFn3 newInt32Array a (notNull x) null
  part a x y = runEffectFn3 newInt32Array a (notNull x) (notNull y)
  empty n = unsafePerformEffect (runEffectFn3 newInt32Array n null null)
  fromArray a = unsafePerformEffect (runEffectFn3 newInt32Array a null null)
  all = _all
  any = _any
  fill = _fill
  set = _set
  map = _map
  traverse = _traverse
  traverse_ = _traverse_
  filter = _filter
  elem = _elem
  unsafeAt = _unsafeAt
  foldlM = _foldlM
  foldl1M = _foldl1M
  foldrM = _foldrM
  foldr1M = _foldr1M
  find = _find
  findIndex = _findIndex
  indexOf = _indexOf
  lastIndexOf = _lastIndexOf
instance typedArrayInt16 :: TypedArray Int16 Int where
  whole a = unsafePerformEffect (runEffectFn3 newInt16Array a null null)
  remainder a x = runEffectFn3 newInt16Array a (notNull x) null
  part a x y = runEffectFn3 newInt16Array a (notNull x) (notNull y)
  empty n = unsafePerformEffect (runEffectFn3 newInt16Array n null null)
  fromArray a = unsafePerformEffect (runEffectFn3 newInt16Array a null null)
  all = _all
  any = _any
  fill = _fill
  set = _set
  map = _map
  traverse = _traverse
  traverse_ = _traverse_
  filter = _filter
  elem = _elem
  unsafeAt = _unsafeAt
  foldlM = _foldlM
  foldl1M = _foldl1M
  foldrM = _foldrM
  foldr1M = _foldr1M
  find = _find
  findIndex = _findIndex
  indexOf = _indexOf
  lastIndexOf = _lastIndexOf
instance typedArrayInt8 :: TypedArray Int8 Int where
  whole a = unsafePerformEffect (runEffectFn3 newInt8Array a null null)
  remainder a x = runEffectFn3 newInt8Array a (notNull x) null
  part a x y = runEffectFn3 newInt8Array a (notNull x) (notNull y)
  empty n = unsafePerformEffect (runEffectFn3 newInt8Array n null null)
  fromArray a = unsafePerformEffect (runEffectFn3 newInt8Array a null null)
  all = _all
  any = _any
  fill = _fill
  set = _set
  map = _map
  traverse = _traverse
  traverse_ = _traverse_
  filter = _filter
  elem = _elem
  unsafeAt = _unsafeAt
  foldlM = _foldlM
  foldl1M = _foldl1M
  foldrM = _foldrM
  foldr1M = _foldr1M
  find = _find
  findIndex = _findIndex
  indexOf = _indexOf
  lastIndexOf = _lastIndexOf
instance typedArrayFloat32 :: TypedArray Float32 Number where
  whole a = unsafePerformEffect (runEffectFn3 newFloat32Array a null null)
  remainder a x = runEffectFn3 newFloat32Array a (notNull x) null
  part a x y = runEffectFn3 newFloat32Array a (notNull x) (notNull y)
  empty n = unsafePerformEffect (runEffectFn3 newFloat32Array n null null)
  fromArray a = unsafePerformEffect (runEffectFn3 newFloat32Array a null null)
  all = _all
  any = _any
  fill = _fill
  set = _set
  map = _map
  traverse = _traverse
  traverse_ = _traverse_
  filter = _filter
  elem = _elem
  unsafeAt = _unsafeAt
  foldlM = _foldlM
  foldl1M = _foldl1M
  foldrM = _foldrM
  foldr1M = _foldr1M
  find = _find
  findIndex = _findIndex
  indexOf = _indexOf
  lastIndexOf = _lastIndexOf
instance typedArrayFloat64 :: TypedArray Float64 Number where
  whole a = unsafePerformEffect (runEffectFn3 newFloat64Array a null null)
  remainder a x = runEffectFn3 newFloat64Array a (toNullable (Just x)) null
  part a x y = runEffectFn3 newFloat64Array a (notNull x) (notNull y)
  empty n = unsafePerformEffect (runEffectFn3 newFloat64Array n null null)
  fromArray a = unsafePerformEffect (runEffectFn3 newFloat64Array a null null)
  all = _all
  any = _any
  fill = _fill
  set = _set
  map = _map
  traverse = _traverse
  traverse_ = _traverse_
  filter = _filter
  elem = _elem
  unsafeAt = _unsafeAt
  foldlM = _foldlM
  foldl1M = _foldl1M
  foldrM = _foldrM
  foldr1M = _foldr1M
  find = _find
  findIndex = _findIndex
  indexOf = _indexOf
  lastIndexOf = _lastIndexOf

-- | Fill the array with a value
_fill :: forall a t. ArrayView a -> t -> Range -> Effect Unit
_fill a x mz = case mz of
  Nothing -> runEffectFn4 fillImpl a x null null
  Just (Tuple s mq) -> case mq of
    Nothing -> runEffectFn4 fillImpl a x (notNull s) null
    Just e -> runEffectFn4 fillImpl a x (notNull s) (notNull e)

-- | Stores multiple values into the typed array
_set :: forall a t. ArrayView a -> Maybe Offset -> Array t -> Effect Unit
_set a mo x = runEffectFn3 setImpl a (toNullable mo) x

-- | Maps a new value over the typed array, creating a new buffer and typed array as well.
_map :: forall a t. (t -> Offset -> t) -> ArrayView a -> ArrayView a
_map f a = unsafePerformEffect (runEffectFn2 mapImpl a (mkEffectFn2 (\x o -> pure (f x o))))

-- | Traverses over each value, returning a new one
_traverse :: forall a t. (t -> Offset -> Effect t) -> ArrayView a -> Effect (ArrayView a)
_traverse f a = runEffectFn2 mapImpl a (mkEffectFn2 f)

-- | Traverses over each value
_traverse_ :: forall a t. (t -> Offset -> Effect Unit) -> ArrayView a -> Effect Unit
_traverse_ f a = runEffectFn2 forEachImpl a (mkEffectFn2 f)

-- | Test a predicate to pass on all values
_all :: forall a t. (t -> Offset -> Boolean) -> ArrayView a -> Boolean
_all p a = runFn2 everyImpl a (mkFn2 p)

-- | Test a predicate to pass on any value
_any :: forall a t. (t -> Offset -> Boolean) -> ArrayView a -> Boolean
_any p a = runFn2 someImpl a (mkFn2 p)

-- | Returns a new typed array with all values that pass the predicate
_filter :: forall a t. (t -> Offset -> Boolean) -> ArrayView a -> ArrayView a
_filter p a = runFn2 filterImpl a (mkFn2 p)

-- | Tests if a value is an element of the typed array
_elem :: forall a t. t -> Maybe Offset -> ArrayView a -> Boolean
_elem x mo a = runFn3 includesImpl a x (toNullable mo)

-- | Fetch element at index.
_unsafeAt :: forall a t. Offset -> ArrayView a -> Effect t
_unsafeAt o a = runEffectFn2 unsafeAtImpl a o

-- | Folding from the left
_foldlM :: forall a t b. (b -> t -> Offset -> Effect b) -> b -> ArrayView a -> Effect b
_foldlM f i a = runEffectFn3 reduceImpl a (mkEffectFn3 f) i

-- | Assumes the typed array is non-empty
_foldl1M :: forall a t. (t -> t -> Offset -> Effect t) -> ArrayView a -> Effect t
_foldl1M f a = runEffectFn2 reduce1Impl a (mkEffectFn3 f)

-- | Folding from the right
_foldrM :: forall a t b. (t -> b -> Offset -> Effect b) -> b -> ArrayView a -> Effect b
_foldrM f i a = runEffectFn3 reduceRightImpl a (mkEffectFn3 (\acc x o -> f x acc o)) i

-- | Assumes the typed array is non-empty
_foldr1M :: forall a t. (t -> t -> Offset -> Effect t) -> ArrayView a -> Effect t
_foldr1M f a = runEffectFn2 reduceRight1Impl a (mkEffectFn3 (\acc x o -> f x acc o))

-- | Returns the first value satisfying the predicate
_find :: forall a t. (t -> Offset -> Boolean) -> ArrayView a -> Maybe t
_find f a = toMaybe (runFn2 findImpl a (mkFn2 f))

-- | Returns the first index of the value satisfying the predicate
_findIndex :: forall a t. (t -> Offset -> Boolean) -> ArrayView a -> Maybe Offset
_findIndex f a = toMaybe (runFn2 findIndexImpl a (mkFn2 f))

-- | Returns the first index of the element, if it exists, from the left
_indexOf :: forall a t. t -> Maybe Offset -> ArrayView a -> Maybe Offset
_indexOf x mo a = toMaybe (runFn3 indexOfImpl a x (toNullable mo))

-- | Returns the first index of the element, if it exists, from the right
_lastIndexOf :: forall a t. t -> Maybe Offset -> ArrayView a -> Maybe Offset
_lastIndexOf x mo a = toMaybe (runFn3 lastIndexOfImpl a x (toNullable mo))

foldl :: forall a b t. TypedArray a t => (b -> t -> Offset -> b) -> b -> ArrayView a -> b
foldl f i a = unsafePerformEffect (foldlM (\acc x o -> pure (f acc x o)) i a)

foldr :: forall a b t. TypedArray a t => (t -> b -> Offset -> b) -> b -> ArrayView a -> b
foldr f i a = unsafePerformEffect (foldrM (\x acc o -> pure (f x acc o)) i a)

foldl1 :: forall a t. TypedArray a t => (t -> t -> Offset -> t) -> ArrayView a -> t
foldl1 f a = unsafePerformEffect (foldl1M (\acc x o -> pure (f acc x o)) a)

foldr1 :: forall a t. TypedArray a t => (t -> t -> Offset -> t) -> ArrayView a -> t
foldr1 f a = unsafePerformEffect (foldr1M (\x acc o -> pure (f x acc o)) a)


foreign import copyWithinImpl :: forall a. EffectFn4 (ArrayView a) Offset Offset (Nullable Offset) Unit

-- | Internally copy values - see [MDN's spec](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/TypedArray/copyWithin) for details.
copyWithin :: forall a. ArrayView a -> Offset -> Offset -> Maybe Offset -> Effect Unit
copyWithin a t s me = runEffectFn4 copyWithinImpl a t s (toNullable me)

foreign import reverseImpl :: forall a. EffectFn1 (ArrayView a) Unit

-- | Reverses a typed array in-place.
reverse :: forall a. ArrayView a -> Effect Unit
reverse = runEffectFn1 reverseImpl

foreign import setImpl :: forall a b. EffectFn3 (ArrayView a) (Nullable Offset) b Unit


-- | Stores multiple values in the typed array, reading input values from the second typed array.
setTyped :: forall a. ArrayView a -> Maybe Offset -> ArrayView a -> Effect Unit
setTyped a mo x = runEffectFn3 setImpl a (toNullable mo) x


-- | Copy the entire contents of the typed array into a new buffer.
foreign import sliceImpl :: forall a. Fn3 (ArrayView a) (Nullable Offset) (Nullable Offset) (ArrayView a)

-- | Copy part of the contents of a typed array into a new buffer, between some start and end indices.
slice :: forall a. ArrayView a -> Range -> ArrayView a
slice a mz = case mz of
  Nothing -> runFn3 sliceImpl a null null
  Just (Tuple s me) -> case me of
    Nothing -> runFn3 sliceImpl a (notNull s) null
    Just e -> runFn3 sliceImpl a (notNull s) (notNull e)


foreign import sortImpl :: forall a. EffectFn1 (ArrayView a) Unit

-- | Sorts the values in-place
sort :: forall a. ArrayView a -> Effect Unit
sort = runEffectFn1 sortImpl


foreign import subArrayImpl :: forall a. Fn3 (ArrayView a) (Nullable Offset) (Nullable Offset) (ArrayView a)

-- | Returns a new typed array view of the same buffer, beginning at the index and ending at the second.
-- |
-- | **Note**: there is really peculiar behavior with `subArray` - if the first offset argument is omitted, or
-- | is `0`, and likewise if the second argument is the length of the array, then the "sub-array" is actually a
-- | mutable replica of the original array - the sub-array reference reflects mutations to the original array.
-- | However, when the sub-array is is actually a smaller contiguous portion of the array, then it behaves
-- | purely, because JavaScript interally calls `Data.ArrayBuffer.ArrayBuffer.slice`.
subArray :: forall a. ArrayView a -> Range -> ArrayView a
subArray a mz = case mz of
  Nothing -> runFn3 subArrayImpl a null null
  Just (Tuple s me) -> case me of
    Nothing -> runFn3 subArrayImpl a (notNull s) null
    Just e -> runFn3 subArrayImpl a (notNull s) (notNull e)


-- | Prints array to a comma-separated string - see [MDN's spec](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/TypedArray/toString) for details.
foreign import toString :: forall a. ArrayView a -> String

foreign import joinImpl :: forall a. Fn2 (ArrayView a) String String

-- | Prints array to a delimiter-separated string - see [MDN's spec](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/TypedArray/join) for details.
toString' :: forall a. ArrayView a -> String -> String
toString' = runFn2 joinImpl


foreign import unsafeAtImpl :: forall a b. EffectFn2 (ArrayView a) Offset b

foreign import hasIndexImpl :: forall a. Fn2 (ArrayView a) Offset Boolean

-- | Determine if a certain index is valid.
hasIndex :: forall a. ArrayView a -> Offset -> Boolean
hasIndex = runFn2 hasIndexImpl

-- | Fetch element at index.
at :: forall a t. TypedArray a t => ArrayView a -> Offset -> Maybe t
at a n = do
  if a `hasIndex` n
    then Just (unsafePerformEffect (unsafeAt n a))
    else Nothing

infixl 3 at as !


foreign import toArrayImpl :: forall a b. ArrayView a -> Array b

-- | Turn typed array into an array.
toArray :: forall a t. TypedArray a t => ArrayView a -> Array t
toArray = toArrayImpl
