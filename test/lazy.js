const { expect } = require("chai");
const { ethers } = require("hardhat");
const { LazyMinter } = require('../lib')
async function deploy() {
  const [minter, redeemer, _] = await ethers.getSigners()
  console.log("Redeemer: ",redeemer.address)
  console.log("minter: ",minter.address)
  let factory = await ethers.getContractFactory("LazyNFT", minter)
  const contract = await factory.deploy(minter.address)
  // the redeemerContract is an instance of the contract that's wired up to the redeemer's signing key
  const redeemerFactory = factory.connect(redeemer)
  const redeemerContract = redeemerFactory.attach(contract.address)
  return {
    minter,
    redeemer,
    contract,
    redeemerContract,
  }
}
describe("ERC1155Lazyminting", function() {
  it("Should deploy", async function() {
    const signers = await ethers.getSigners();
    const minter = signers[0].address;
    const ERC1155Lazyminting = await ethers.getContractFactory("ERC1155Lazyminting");
    const ERC1155lazyminting = await ERC1155Lazyminting.deploy("0x56715d15149f12c474a73098610dec7078340447","ipfs:/");
    await ERC1155lazyminting.deployed();
  });
  it("Should redeem an NFT from a signed voucher", async function() {
    const { contract, redeemerContract, redeemer, minter } = await deploy()
    const lazyMinter = new LazyMinter({ contractAddress: contract.address, signer: minter })
    const { voucher, signature } = await lazyMinter.createVoucher(1, 1000,"ipfs://bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi")
    await expect(redeemerContract.redeem(minter,redeemer.address, voucher))
      .to.emit(contract, 'safeTransferFrom')  // transfer from null address to minter
      .withArgs('0x0000000000000000000000000000000000000000', minter.address, voucher.tokenId, voucher.amount,signature)
      .and.to.emit(contract, 'safeTransferFrom') // transfer from minter to redeemer
      .withArgs(minter.address, redeemer.address, voucher.tokenId,voucher.amount,signature);
  });
});
