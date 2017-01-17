module Data.ArrayBuffer.ArrayBuffer( ARRAYBUFFER()
                                   , create
                                   , byteLength
                                   , slice
                                   , fromArray
                                   , fromString
                                   ) where

import Control.Monad.Eff (Eff)
import Data.Function.Uncurried (Fn3, runFn3)
import Data.ArrayBuffer.Types (ArrayBuffer, ByteOffset, ByteLength)

foreign import data ARRAYBUFFER :: !

-- | Create an `ArrayBuffer` with the given capacity.
foreign import create :: forall e. ByteLength -> Eff (arrayBuffer :: ARRAYBUFFER | e) ArrayBuffer

-- | Represents the length of an `ArrayBuffer` in bytes.
foreign import byteLength :: forall e. ArrayBuffer -> Eff (arrayBuffer :: ARRAYBUFFER | e) ByteLength

foreign import sliceImpl :: forall e. Fn3 ByteOffset ByteOffset ArrayBuffer (Eff (arrayBuffer :: ARRAYBUFFER | e) ArrayBuffer)

-- | Returns a new `ArrayBuffer` whose contents are a copy of this ArrayBuffer's bytes from begin, inclusive, up to end, exclusive.
slice :: forall e. ByteOffset -> ByteOffset -> ArrayBuffer -> Eff (arrayBuffer :: ARRAYBUFFER | e) ArrayBuffer
slice = runFn3 sliceImpl

-- | Convert an array into an `ArrayBuffer` representation.
foreign import fromArray :: forall e. Array Number -> Eff (arrayBuffer :: ARRAYBUFFER | e) ArrayBuffer

-- | Convert a string into an `ArrayBuffer` representation.
foreign import fromString :: forall e. String -> Eff (arrayBuffer :: ARRAYBUFFER | e) ArrayBuffer
