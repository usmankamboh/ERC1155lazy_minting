const hre = require("hardhat");
async function main() {
  const ERC1155Lazyminting = await hre.ethers.getContractFactory("ERC1155Lazyminting");
  const ERC1155lazyminting = await ERC1155Lazyminting.deploy("0x56715d15149f12c474a73098610dec7078340447","ipfs:/");
  await ERC1155lazyminting.deployed();
  console.log("ERC1155Lazyminting deployed to:", ERC1155lazyminting.address);
}
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
