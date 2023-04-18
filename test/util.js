function numToBN(number, decimals = 18) {
  return ethers.utils.parseUnits(number.toString(), decimals);
}

function bnToNum(bn, decimals = 18) {
  return ethers.utils.formatUnits(bn, decimals);
}

module.exports = {
  numToBN,
  bnToNum,
};
