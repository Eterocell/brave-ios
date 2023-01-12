/* Copyright 2022 The Brave Authors. All rights reserved.
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import BraveCore

struct ERC721Metadata: Codable, Equatable {
  var imageURLString: String?
  var name: String?
  var description: String?
  
  enum CodingKeys: String, CodingKey {
    case imageURLString = "image"
    case name
    case description
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.imageURLString = try container.decodeIfPresent(String.self, forKey: .imageURLString)
    self.name = try container.decodeIfPresent(String.self, forKey: .name)
    self.description = try container.decodeIfPresent(String.self, forKey: .description)
  }
  
  init(
    imageURLString: String?,
    name: String?,
    description: String?
  ) {
    self.imageURLString = imageURLString
    self.name = name
    self.description = description
  }
  
  var imageURL: URL? {
    guard let urlString = imageURLString else { return nil }
    return URL(string: urlString)
  }
}

class NFTDetailStore: ObservableObject {
  private let rpcService: BraveWalletJsonRpcService
  let nft: BraveWallet.BlockchainToken
  @Published var isLoading: Bool = false
  @Published var erc721Metadata: ERC721Metadata?
  @Published var networkInfo: BraveWallet.NetworkInfo = .init()
  let braveCore: BraveCoreMain?
  
  init(
    rpcService: BraveWalletJsonRpcService,
    nft: BraveWallet.BlockchainToken,
    erc721Metadata: ERC721Metadata?,
    braveCore: BraveCoreMain?
  ) {
    self.rpcService = rpcService
    self.nft = nft
    self.erc721Metadata = erc721Metadata
    self.braveCore = braveCore
  }
  
  func update() {
    Task { @MainActor in
      let allNetworks = await rpcService.allNetworks(nft.coin)
      if let network = allNetworks.first(where: { $0.chainId.caseInsensitiveCompare(nft.chainId) == .orderedSame }) {
        networkInfo = network
      }
      
      if erc721Metadata == nil {
        isLoading = true
        
        let (metaData, _, _) = await rpcService.erc721Metadata(nft.contractAddress, tokenId: nft.tokenId, chainId: nft.chainId)
        
        isLoading = false
        if let data = metaData.data(using: .utf8),
           var result = try? JSONDecoder().decode(ERC721Metadata.self, from: data) {
            if result.imageURLString != nil && result.imageURLString!.hasPrefix("ipfs://") {
                result.imageURLString = braveCore?.ipfsAPI.resolveGatewayUrl(for: result.imageURLString!)?.absoluteString
            }
          erc721Metadata = result
        }
      }
    }
  }
}
