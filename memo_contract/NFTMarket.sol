// "SPDX-License-Identifier: UNLICENSED"
pragma solidity ^0.8.4;

// カウンター管理（インクリメントする数字）
import "@openzeppelin/contracts/utils/Counters.sol";

// ERC721
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

// 再入回避
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

//--------------------------
// マーケットコントラクト
//--------------------------
contract NFTMarket is ReentrancyGuard {
    // カウンター
    using Counters for Counters.Counter;
    Counters.Counter private _itemIds;      // 発行済みのアイテムID & 販売累計数
    Counters.Counter private _itemsSold;    // 販売個数

    // コントラクトのオーナー
    // [Ownerable.sol]で置き換えても良いかも
    address payable owner;

    // 掲載料（出品時に出品者に払い込ませ、NFTが売却されたらオーナーに払われる手数料）
    uint256 listingPrice = 0.025 ether; // 実際は整数
    // uint listingFeeRate = 100; // 小数点は基本的に使わない
    // ex. price * listingFeeRate / 10000
    // setter関数に変えるべき onlyOwner()修飾子

    //--------------------
    // コンストラクタ
    //--------------------
    constructor() {
        owner = payable(msg.sender);
    }

    //--------------------
    // アイテム構造体
    //--------------------
    struct MarketItem {
        uint256 itemId;             // アイテムID（これはいらないかも）
        address nftContract;        // コントラクトアドレス
        uint256 tokenId;            // トークンID(nftContract内でのID)
        address payable seller;     // 販売者
        address payable owner;      // 購入者
        uint256 price;              // 価格
        bool isSold;                  // 販売済みフラグ
    }

        // 変数名の頭に型をつける
    //   struct MarketItem { 
    //     uint256 uItemId;
    //     address aNftContract;
    //     uint256 uTokenId;
    //     address payable aSeller;
    //     address payable aOwner;
    //     uint256 uPrice;
    //     bool bIsSold;
    // }


    // 販売アイテムのマップ（itemIdでマッピングされる）
    mapping(uint256 => MarketItem) private idToMarketItem;

    // 出品イベント
    event MarketItemCreated(
        uint256 indexed itemId,         // アイテムのID
        address indexed nftContract,    // NFTのコントラクトアドレス
        uint256 indexed tokenId,        // NFTのID(nftContract内でのID)
        address seller,                 // 販売者
        address owner,                  // 保有者（購入者）
        uint256 price,                  // 価格
        bool isSold                       // 販売済みフラグ
    );

    /* Returns the listing price of the contract */
    // [public/view]
    // 掲載料の確認
    function getListingPrice() public view returns (uint256) {
        return listingPrice;
    }

    /* Places an item for sale on the marketplace */
    //---------------------------------------------------------
    // [public/payable] トークンの販売
    //---------------------------------------------------------
    // 商品の販売を開始する（指定のトークンを販売アイテムとして登録）
    // 掲載料をコントラクトへ預託する
    // 重複登録チェックをしていないのでは？
    //---------------------------------------------------------
    function createMarketItem(
        address nftContract,
        uint256 tokenId,
        uint256 price
    ) public payable nonReentrant {
        // 整合性の判定をしたほうがお行儀はよい（チェックがなくても[_transferFrom]でrevertされるはず）
        // ・[nftContract]が[ERC721]に準拠したコントラクトか？
        // ・[tokenId]が存在するか？
        // ・msg.senderが[tokenId]の保有者か？

        require(price > 0, "Price must be at least 1 wei");
        require(
            msg.value == listingPrice,
            "Price must be equal to listing price"
        );

        // アイテムIDの確定＆取得
        _itemIds.increment();   // このインクリメントを後にした方が処理が楽になるかも？（各種IDの+1がいらなくなるが、IDが０始めになる）
        uint256 itemId = _itemIds.current();
        // ↑を入れ替えれば下のi+1は不要
        // uint256 itemId = _itemIds.current();
        // _itemIds.increment()

        // アイテムデータの作成
        idToMarketItem[itemId] = MarketItem(
            itemId,
            nftContract,
            tokenId,
            payable(msg.sender),
            payable(address(0)),
            price,
            false
        );

        // safeTransferFromのほうが今風かも
        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);

        // イベントの発火
        emit MarketItemCreated(
            itemId,
            nftContract,
            tokenId,
            msg.sender,
            address(0),
            price,
            false
        );
    }

    /* Creates the sale of a marketplace item */
    /* Transfers ownership of the item, as well as funds between parties */
    //---------------------------------------------------------
    // [public/payable] NFTの購入
    //---------------------------------------------------------    
    // この処理を呼び出したアカウントによるアイテムの購入
    // 価格の１００％が販売者へ送られる
    // コントラクトのオーナーへ掲載料が支払われる
    //--------------------------------------------------------- 
    // 関数名に議論の余地あり ex.buyItem
    // 引数のaddress nftContractは省略可能       
    function createMarketSale(address nftContract, uint256 itemId)
        public
        payable
        nonReentrant
    {
        // nftContractは不要？（MarketItem.nftContractが利用できるのでは？）

        // チェックが必要そう
        // ・itemIdの整合性
        // ・すでに販売済みか？（おそらく同じユーザーが売買を繰り返した場合古いアイテムデータに対して処理ができてしまいそう）
        // soldフラグのチェックをしていないので二重販売・購入可能

        uint256 price = idToMarketItem[itemId].price;
        uint256 tokenId = idToMarketItem[itemId].tokenId;
        // uint256 nftContract =  MarketItem.nftContract;
        require(
            msg.value == price,
            "Please submit the asking price in order to complete the purchase"
        );

        idToMarketItem[itemId].seller.transfer(msg.value);
        IERC721(nftContract).transferFrom(address(this), msg.sender, tokenId);
        idToMarketItem[itemId].owner = payable(msg.sender); // payableはなくても良い？
        idToMarketItem[itemId].isSold = true;
        _itemsSold.increment();
        payable(owner).transfer(listingPrice);
    }

    /* Returns all unsold market items */
    //---------------------------------------------------------
    // [public/view] 販売中のアイテムの一覧を返す
    //---------------------------------------------------------
    // アイテムが多量になった場合にはページングが必要そう
    //---------------------------------------------------------
    function fetchMarketItems() public view returns (MarketItem[] memory) {
        uint256 itemCount = _itemIds.current();
        uint256 unsoldItemCount = _itemIds.current() - _itemsSold.current();
        uint256 currentIndex = 0;

        // 枠の確保
        MarketItem[] memory items = new MarketItem[](unsoldItemCount);

        // 返却データの作成
        for (uint256 i = 0; i < itemCount; i++) {
            // soldフラグのほうがよいかも（対して変わらないとは思うが）
            // if (idToMarketItem[i + 1].sold != false )
            if (idToMarketItem[i + 1].owner == address(0)) {
                uint256 currentId = i + 1;
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }

        return items;
    }

    /* Returns only items that a user has purchased */
    //---------------------------------------------------------
    // [public/view] マーケット上で保有するアイテムの一覧を返す
    //---------------------------------------------------------
    // 処理を呼び出したアカウントが、保有するアイテムの一覧を返す
    // 引数にアカウントを指定して汎用化したり、ページングが必要そう
    //---------------------------------------------------------
    function fetchMyNFTs() public view returns (MarketItem[] memory) {
        uint256 totalItemCount = _itemIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        // 個数の算出
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].owner == msg.sender) {
                itemCount += 1;
            }
        }

        // 枠の確保
        MarketItem[] memory items = new MarketItem[](itemCount);

        // 返却データの作成
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].owner == msg.sender) {
                uint256 currentId = i + 1;
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }

        return items;
    }

    /* Returns only items a user has created */
    //---------------------------------------------------------
    // [public/view] 出品アイテムリストの取得
    //---------------------------------------------------------
    // 処理を呼び出したアカウントが、過去に販売したアイテムの一覧を返す
    // 引数にアカウントを指定して汎用化したり、ページングが必要そう
    //---------------------------------------------------------
    function fetchItemsCreated() public view returns (MarketItem[] memory) {
        uint256 totalItemCount = _itemIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        // 個数の算出
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].seller == msg.sender) {
                itemCount += 1;
            }
        }

        // 枠の確保
        MarketItem[] memory items = new MarketItem[](itemCount);

        // 返却データの作成
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].seller == msg.sender) {
                uint256 currentId = i + 1;
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }

        return items;
    }
}
