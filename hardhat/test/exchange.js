const { expect } = require("chai");
const { ethers } = require("hardhat");

let rwaExchange;
let rwaCollection;
let signDocument;
let mockToken;

let tokenOfPayment;
const price = ethers.utils.parseEther("1");
const rwaTokenId = 1;
let buyer;
let seller;

async function createOffer() {
  let transaction = await rwaCollection
    .connect(seller)
    .mint("House", "Cool house", "example.com", "example-img.jpg");
  const transactionReceipt = await transaction.wait();
  const tokenId = transactionReceipt.events[0].args.tokenId.toNumber();

  await rwaCollection.connect(seller).approve(rwaExchange.address, tokenId);
  await rwaExchange.connect(seller).createOffer(tokenOfPayment, price, tokenId);
}

async function placeBid(offerId) {
  await mockToken.connect(buyer).approve(rwaExchange.address, price);
  await rwaExchange.connect(buyer).placeBid(offerId, price);
}

describe("RWAExchange", (accounts) => {
  beforeEach(async () => {
    [buyer, seller] = await ethers.getSigners();

    const MockToken = await ethers.getContractFactory("MockToken");
    mockToken = await MockToken.deploy("Mock Token", "MOCK");
    await mockToken.deployed();
    await mockToken.connect(buyer).mint(buyer.address, price);
    tokenOfPayment = mockToken.address;

    const RWACollection = await ethers.getContractFactory("RWACollection");
    rwaCollection = await RWACollection.deploy("Real World Assets", "RWA");
    await rwaCollection.deployed();

    const SignDocument = await ethers.getContractFactory("SignDocument");
    signDocument = await SignDocument.deploy();
    await signDocument.deployed();

    const RWAExchange = await ethers.getContractFactory("RWAExchange");
    rwaExchange = await RWAExchange.deploy(
      rwaCollection.address,
      signDocument.address
    );
    await rwaExchange.deployed();
  });

  it("should create a new offer", async () => {
    await createOffer();
    const offer = await rwaExchange.offers(0);

    expect(offer.owner).to.equal(seller.address);
    expect(offer.tokenOfPayment).to.equal(tokenOfPayment);
    expect(offer.price).to.equal(price);
    expect(offer.rwaTokenId).to.equal(0);
    expect(offer.completed).to.be.false;
    expect(offer.canceled).to.be.false;
  });

  it("should not create a new offer with invalid token of payment", async () => {
    await expect(
      rwaExchange.createOffer(ethers.constants.AddressZero, price, rwaTokenId)
    ).to.be.revertedWith("Invalid token of payment");
  });

  it("should not create a new offer with invalid price", async () => {
    await expect(
      rwaExchange.createOffer(tokenOfPayment, 0, rwaTokenId)
    ).to.be.revertedWith("Invalid price");
  });

  it("should cancel an offer", async () => {
    await createOffer();
    await rwaExchange.connect(seller).cancelOffer(0);

    const offer = await rwaExchange.offers(0);
    expect(offer.canceled).to.be.true;
  });

  it("should not cancel an offer that was already canceled", async () => {
    await createOffer();
    await rwaExchange.connect(seller).cancelOffer(0);
    await expect(rwaExchange.connect(seller).cancelOffer(0)).to.be.revertedWith(
      "Offer was already canceled"
    );
  });

  it("should place a bid", async () => {
    await createOffer();
    await placeBid(0);
  });

  it("should cancel a bid", async () => {
    await createOffer();
    await placeBid(0);
    await rwaExchange.connect(buyer).cancelBid(0);
    const buyerBalanceAfter = await mockToken.balanceOf(buyer.address);
    expect(buyerBalanceAfter.toString()).to.equal(price.toString());
  });

  it("should put documents to sign", async () => {
    await createOffer();
    await placeBid(0);
    await rwaExchange.connect(seller).acceptBid(0, buyer.address);

    let res = await rwaExchange
      .connect(buyer)
      .putDocumentsToSign(0, [
        "E5F9176ECD90317CF2D4673926C9DB65475B0B58E7F468586DDAEF280A98CDBD",
        "3461164897596E65B79BC0B7BEE8CC7685487E37F52ECF0B34C000329675B859",
      ]);
  });

  it("should return offers", async () => {
    await createOffer();

    const pointer = 0;
    const limit = 1;

    const res = await rwaExchange.connect(buyer).getOffers(pointer, limit);
  });

  it("should return offer bids", async () => {
    await createOffer();
    await placeBid(0);

    const res = await rwaExchange.connect(seller).getAllBids(0);
  });

  /*   it("should return sender's bids", async () => {
    await createOffer();
    await placeBid(0);

    const pointer = 1;
    const limit = 1;

    const res = await rwaExchange
      .connect(buyer)
      .getSenderPlacedBids(pointer, limit);
      console.log(res);
  }); */
});
