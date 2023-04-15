import { ethers } from "ethers";
import { ref } from "vue";

export let provider: ethers.providers.Web3Provider | undefined;
export let signer: ethers.providers.JsonRpcSigner | undefined;
export const address = ref("");
export const balance = ref("");

export function useWallet() {
  function connect(): Promise<ethers.providers.JsonRpcSigner> {
    return new Promise(async (resolve, reject) => {
      provider = new ethers.providers.Web3Provider((window as any).ethereum as any, "any");

      if (!provider) reject("Install metamask");
      try {
        await provider.send("eth_requestAccounts", []);
        signer = provider.getSigner();

        provider = provider;
        address.value = await signer.getAddress();

        (window as any).ethereum.on("accountsChanged", (accounts: any[]) => {
          console.log(`Current user address: ${accounts[0]}`);
          signer = provider?.getSigner(accounts[0]);
          address.value = accounts[0];
        });

        (window as any).ethereum.on("disconnect", () => {
          console.log("Wallet locked or disconnected.");
          connect();
        });

        resolve(signer);
      } catch (error) {
        console.log(error);
        reject("Connect your wallet");
      }
    });
  }

  return { connect };
}
