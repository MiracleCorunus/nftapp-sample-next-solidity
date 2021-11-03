// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

//--------------------
// NFTコントラクト
//--------------------
contract NFT is ERC721URIStorage {
    // カウンター：トークンID
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    // Counterを使う方法は初心者には難しい？よりシンプルなのは↓
    // int256 _tokenIds;
    // _tokenIds++;

    // マーケットコントラクタのアドレス（全てのトークンが販売委託される）
    address contractAddress;

    //--------------------
    // コンストラクタ
    //--------------------
    constructor(address marketplaceAddress) ERC721("Metaverse Tokens", "METT") {
        contractAddress = marketplaceAddress;
    }

    //----------------------
    // トークンのミント
    //----------------------
    function createToken(string memory tokenURI) public returns (uint256) {
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        // uint256 newItemId = _tokenIds;

        _mint(msg.sender, newItemId);

        // トークンURIの設定（metadataの参照先／もしくはmetadataそのもの）
        _setTokenURI(newItemId, tokenURI); 
          // ERC721URIStorage
          // トークンURIをファイル名なりから生成して返す。管理画面から直接実行させればOK

        // トークンごとによばれるのであれば、approveのほうがよいかも
        setApprovalForAll(contractAddress, true);
        // approve(contractAddress, true);
        // このコントラクト内のmsg.senderのトークンを全てコントラクトの管理下における
        // approve: トークン個々の許可の処理


        // 書き込み(トランザクションが発行される呼び出し)では基本的に返り値は指定しない
        // トランザクションの結果までに時差があるためイベントによる情報の通知となる
        // この処理の場合は、"_mint"内部で、"Transfer"イベントが発火される
        return newItemId;
    }
}
