const { ethers, run, network } = require("hardhat");

async function main() {
  console.log(network.config);

  const rwaFactory = await ethers.getContractFactory("RWACollection");
  const rwa_contract = await rwaFactory.deploy("RWACollection", "RWC");
  await rwa_contract.deployed();
  console.log(`RWACollection contract address ${rwa_contract.address}`);

  const docFactory = await ethers.getContractFactory("SignDocument");
  const doc_contract = await docFactory.deploy();
  await doc_contract.deployed();
  console.log(`SignDocument contract address ${doc_contract.address}`);

  const exchangeFactory = await ethers.getContractFactory("RWAExchange");
  const exchange_contract = await exchangeFactory.deploy(rwa_contract.address, doc_contract.address);
  await exchange_contract.deployed();
  console.log(`Exchange contract address ${exchange_contract.address}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
