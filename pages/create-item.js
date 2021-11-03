import { useState } from "react";
import Image from "next/image";
import { ethers } from "ethers";
import { useRouter } from "next/router";
import Web3Modal from "web3modal";
import { create as ipfsHTTPClient } from "ipfs-http-client";

// inferior URL. Should replaced our own pinning service
const client = ipfsHTTPClient("https://ipfs.infura.io:5001/api/v0");

import { nftaddress, nftmarketaddress } from "../config";

import NFT from "../artifacts/contracts/NFT.sol/NFT.json";
import NFTMarket from "../artifacts/contracts/NFTMarket.sol/NFTMarket.json";

export default function CreateItem() {
  const [fileUrl, setFileUrl] = useState(null);
  const [formInput, updateFormInput] = useState({
    price: "",
    name: "",
    description: "",
  });

  const router = useRouter();

  // Save image file to IPFS
  async function onChange(e) {
    const file = e.target.files[0];
    try {
      const added = await client.add(file, {
        progress: (prog) => console.log(`received: ${prog}`),
      });
      const url = `https://ipfs.infura.io/ipfs/${added.path}`;
      setFileUrl(url);
    } catch (e) {
      console.log(e);
    }
  }

  // Save Metadata to IPFS
  async function createItem() {
    const { name, description, price } = formInput;
    if (!name || !description || !price || !fileUrl) {
      alert("Required fields are missing.");
      return;
    }
    const data = JSON.stringify({
      name,
      description,
      image: fileUrl,
    });

    try {
      const added = await client.add(data);
      const url = `https://ipfs.infura.io/ipfs/${added.path}`;
      createSale(url);
    } catch (e) {
      console.log("Error uploading file:", e);
    }
  }

  async function createSale(url) {
    // トランザクションを投げる前に事前判定が必要
    // 判定として、NFT.solに対してisApprovedForAll(metamaskから取得するethアドレス, NFTMarket.address)
    // falseの場合、setApprovalForAll(NFTMarket.address, true)
    // トランザクションが完了してから行ってください
    const web3Modal = new Web3Modal();
    const connection = await web3Modal.connect();
    const provider = new ethers.providers.Web3Provider(connection);
    const signer = provider.getSigner();

    let contract = new ethers.Contract(nftaddress, NFT.abi, signer);
    let transaction = await contract.createToken(url);
    let tx = await transaction.wait();

    let events = tx.events[0];
    let value = events.args[2]; // check the value of transaction
    let tokenId = value.toNumber();

    const price = ethers.utils.parseUnits(formInput.price, "ether");

    contract = new ethers.Contract(nftmarketaddress, NFTMarket.abi, signer);
    let listingPrice = await contract.getListingPrice();

    transaction = await contract.createMarketItem(nftaddress, tokenId, price, {
      value: listingPrice,
    });
    await transaction.wait();
    router.push("/");
  }

  return (
    <div className="flex justify-center">
      <div className="w-1/2 flex flex-col pb-12">
        <input
          className="mt-8 border rounded p-4"
          placeholder="NFT Name"
          onChange={(e) =>
            updateFormInput({ ...formInput, name: e.target.value })
          }
        />
        <textarea
          className="mt-2 border rounded p-4"
          placeholder="NFT Description"
          onChange={(e) =>
            updateFormInput({ ...formInput, description: e.target.value })
          }
        />
        <input
          className="mt-2 border rounded p-4"
          placeholder="NFT Price in Eth"
          onChange={(e) =>
            updateFormInput({ ...formInput, price: e.target.value })
          }
        />
        <input className="my-4" type="file" name="Asset" onChange={onChange} />
        {fileUrl && (
          <Image
            src={fileUrl}
            alt={""}
            width="360"
            height="280"
            layout={"intrinsic"}
            objectFit={"cover"}
            objectPosition={"50% 50%"}
          />
        )}
        <button
          className="font-bold mt-4 bg-pink-500 text-white rounded p-4 shadow-lg"
          onClick={createItem}
        >
          Create a NFT
        </button>
      </div>
    </div>
  );
}
