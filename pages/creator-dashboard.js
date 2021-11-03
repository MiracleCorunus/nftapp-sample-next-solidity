import { ethers } from "ethers";
import { useEffect, useState } from "react";
import axios from "axios";
import Web3Modal from "web3modal";
import Image from "next/image";

import { nftmarketaddress, nftaddress } from "../config";

import NFTMarket from "../artifacts/contracts/NFTMarket.sol/NFTMarket.json";
import NFT from "../artifacts/contracts/NFT.sol/NFT.json";

export default function CreatorDashboard() {
  const [nfts, setNfts] = useState([]);
  const [soldNfts, setSoldNfts] = useState([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    loadNFTs();
  }, []);

  async function loadNFTs() {
    const web3Modal = new Web3Modal();
    const connection = await web3Modal.connect();
    const provider = new ethers.providers.Web3Provider(connection);
    const signer = provider.getSigner();

    const marketContract = new ethers.Contract(
      nftmarketaddress,
      NFTMarket.abi,
      signer
    );

    const tokenContract = new ethers.Contract(nftaddress, NFT.abi, provider);
    const data = await marketContract.fetchItemsCreated();

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
          isSold: i.isSold,
          image: meta.data.image,
        };
        return item;
      })
    );

    const soldItems = items.filter((item) => item.isSold);
    setSoldNfts(soldItems);
    setNfts(items);
    setIsLoading(false);
  }

  return (
    <>
      <div className="p-4">
        <h2 className="text-2xl py-2">Items Created</h2>
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 pt-4">
          {nfts.map((nft, i) => (
            <div className="border shadow rounded-xl overflow-hidden" key={i}>
              <Image
                className="rounded"
                src={nft.image}
                alt={nft.name}
                width="360"
                height="280"
                layout={"intrinsic"}
                objectFit={"cover"}
                objectPosition={"50% 50%;"}
              />
              <div className="p-4 bg-black">
                <p className="text-2xl font-bold text-white">
                  Price - {nft.price} Eth
                </p>
              </div>
            </div>
          ))}
        </div>
      </div>
      <div className="px-4">
        {Boolean(soldNfts.length) && (
          <div>
            <h2 className="text-2xl py-2">Items Sold</h2>
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols4 gap-4 pt-4">
              {soldNfts.map((nft, i) => (
                <div
                  className="border shadow rounded-xl overflow-hidden"
                  key={i}
                >
                  <Image
                    className="rounded"
                    src={nft.image}
                    alt={nft.name}
                    width="360"
                    height="280"
                    layout={"intrinsic"}
                    objectFit={"cover"}
                    objectPosition={"50% 50%;"}
                  />
                  <div className="p-4 bg-black">
                    <p className="text-2xl font-bold text-white">
                      Price- {nft.price} Eth
                    </p>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}
      </div>
    </>
  );
}
