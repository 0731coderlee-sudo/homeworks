import {
  Bought as BoughtEvent,
  Listed as ListedEvent,
  TokenAdded as TokenAddedEvent,
  TokenRemoved as TokenRemovedEvent
} from "../generated/NFTMarket/NFTMarket"
import { List, BuyNFT, TokenAdded, TokenRemoved } from "../generated/schema"
import { BaseERC721 } from "../generated/NFTMarket/BaseERC721"
import { Address, BigInt, Bytes } from "@graphprotocol/graph-ts"

// Helper function to generate unique List ID from nft address and tokenId
// Using a simple approach: nft address bytes + tokenId as hex string
function getListId(nft: Address, tokenId: BigInt): Bytes {
  // Create a unique ID by combining nft address and tokenId
  // Convert both to hex strings and combine
  let nftHex = nft.toHexString()
  let tokenIdHex = tokenId.toHexString()
  // Remove 0x prefixes and pad tokenId to 64 chars (32 bytes)
  let nftPart = nftHex.length >= 42 ? nftHex.slice(2) : nftHex
  let tokenPart = tokenIdHex.length >= 2 ? tokenIdHex.slice(2) : tokenIdHex
  // Pad tokenId part to 64 characters
  let paddedToken = tokenPart
  let len = tokenPart.length
  while (len < 64) {
    paddedToken = "0" + paddedToken
    len = len + 1
  }
  // Combine and convert back to Bytes
  let combined = "0x" + nftPart + paddedToken
  return Bytes.fromHexString(combined)
}

export function handleListed(event: ListedEvent): void {
  // Generate unique ID for List entity using nft address + tokenId
  let listId = getListId(event.params.nft, event.params.tokenId)
  let entity = new List(listId)
  
  entity.nft = event.params.nft
  entity.tokenId = event.params.tokenId
  entity.seller = event.params.seller
  entity.price = event.params.price
  entity.payToken = event.params.paymentToken
  
  // Call NFT contract to get tokenURI
  let nftContract = BaseERC721.bind(event.params.nft)
  let tokenURICall = nftContract.try_tokenURI(event.params.tokenId)
  if (tokenURICall.reverted) {
    // If call fails, use empty string or default value
    entity.tokenURL = ""
  } else {
    entity.tokenURL = tokenURICall.value
  }
  
  // Set deadline (not available in event, set to 0 or could be calculated)
  entity.deadline = BigInt.zero()
  
  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash
  
  // Initialize optional fields
  entity.cancelTxHash = null
  entity.filledTxHash = null

  entity.save()
}

export function handleBought(event: BoughtEvent): void {
  // Create BuyNFT entity
  let buyEntity = new BuyNFT(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  
  buyEntity.buyer = event.params.buyer
  // Fee can be 0 or calculated from price difference, for now set to 0
  buyEntity.fee = BigInt.zero()
  
  buyEntity.blockNumber = event.block.number
  buyEntity.blockTimestamp = event.block.timestamp
  buyEntity.transactionHash = event.transaction.hash
  
  // Find the corresponding List entity
  let listId = getListId(event.params.nft, event.params.tokenId)
  let listEntity = List.load(listId)
  
  if (listEntity != null) {
    // Establish relation - use the list ID as Bytes
    // Note: List is immutable, so we cannot update filledTxHash
    // The filled status can be inferred from the existence of BuyNFT with relation
    buyEntity.list = listId
  }

  buyEntity.save()
}

export function handleTokenAdded(event: TokenAddedEvent): void {
  let entity = new TokenAdded(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.token = event.params.token

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleTokenRemoved(event: TokenRemovedEvent): void {
  let entity = new TokenRemoved(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.token = event.params.token

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}
