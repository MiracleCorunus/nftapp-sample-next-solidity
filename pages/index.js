import { ethers } from "ethers";
import { useEffect, useState } from "react";
import axios from "axios";
import Web3Modal from "web3modal";
import Image from "next/image";
import { nftaddress, nftmarketaddress } from "../config";

import NFT from "../artifacts/contracts/NFT.sol/NFT.json";
import NFTMarket from "../artifacts/contracts/NFTMarket.sol/NFTMarket.json";

export default function Home() {
  const [nfts, setNfts] = useState([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    loadNFTs();
  }, []);

  async function loadNFTs() {
    const provider = new ethers.providers.JsonRpcProvider();
    const tokenContract = new ethers.Contract(nftaddress, NFT.abi, provider);
    const marketContract = new ethers.Contract(
      nftmarketaddress,
      NFTMarket.abi,
      provider
    );
    // console.log("fetchMarketItemsを呼ぶ直前");
    const data = await marketContract.fetchMarketItems();
    // console.log("fetchMarketItemsを呼んだ直後", data);
    const items = await Promise.all(
      data.map(async (i) => {
        const tokenUri = await tokenContract.tokenURI(i.tokenId);
        const meta = await axios.get(tokenUri);
        let price = ethers.utils.formatUnits(i.price.toString(), "ether");
        let item = {
          price,
          tokenId: i.tokenId.toNumber(),
          seller: i.seller,
          owner: i.owner,
          image: meta.data.image,
          name: meta.data.name,
          description: meta.data.description,
          isSold: false,
          isCanceled: false,
        };
        return item;
      })
    );
    setNfts(items);
    setIsLoading(false);
  }

  async function buyNft(nft) {
    const web3Modal = new Web3Modal();
    const connection = await web3Modal.connect();
    const provider = new ethers.providers.Web3Provider(connection);

    const signer = provider.getSigner();
    const marketContract = new ethers.Contract(
      nftmarketaddress,
      NFTMarket.abi,
      signer
    );

    const price = ethers.utils.parseUnits(nft.price.toString(), "ether");

    const transaction = await marketContract.buyMarketItem(
      nftaddress,
      nft.tokenId,
      { value: price }
    );
    await transaction.wait();
    loadNFTs();
  }

  if (isLoading === false && !nfts.length) {
    return <h1 className="px-20 y-10 text-3xl "> No items in marketplace</h1>;
  }

  return (
    <div className="flex justify-center">
      <div className="px-4" style={{ maxWidth: "1600px" }}>
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 pt-4">
          {nfts.map((nft, i) => (
            <div key={i} className="border shadow rounded-xl overflow-hidden">
              <Image
                src={nft.image}
                alt={nft.name}
                width="360"
                height="280"
                layout={"intrinsic"}
                objectFit={"cover"}
                objectPosition={"50% 50%;"}
              />
              <div className="p-4">
                <p
                  className="text-2xl font-semibold"
                  style={{ height: "64px" }}
                >
                  {nft.name}
                </p>
                <div style={{ height: "70px", overflow: "hidden" }}>
                  <p className="text-gray-400">{nft.description}</p>
                </div>
              </div>
              <div className="p-4 bg-black">
                <p className="text-2xl mb-4 font-bold text-white">
                  {nft.price} Eth
                </p>
                <button
                  className="w-full bg-pink-500 text-white font-bold py-2 px-12 rounded"
                  onClick={() => buyNft(nft)}
                >
                  Buy
                </button>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
