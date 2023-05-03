require("dotenv").config();
require("@nomiclabs/hardhat-etherscan");
require("@nomiclabs/hardhat-waffle");
require("hardhat-gas-reporter");
require("hardhat-contract-sizer");
require("solidity-coverage");
require("@openzeppelin/hardhat-upgrades");

module.exports = {
    contractSizer: {
        alphaSort: true,
        runOnCompile: true,
        disambiguatePaths: false,
    },
    solidity: {
        version: "0.8.19",
        settings: {
            optimizer: {
                enabled: true,
                runs: 1000000,
            },
        },
    },
    networks: {
        hardhat: {
            allowUnlimitedContractSize: true,
        },
        goerli: {
            url: "https://rpc.ankr.com/eth_goerli",
            accounts: [process.env.PRIVATE_KEY],
        },
        arbitrumGoerli: {
            url: "https://goerli-rollup.arbitrum.io/rpc",
            accounts: [process.env.PRIVATE_KEY],
        },
        ethereum: {
            url: "https://eth.llamarpc.com",
            accounts: [process.env.PRIVATE_KEY],
        }
    },
    etherscan: {
        apiKey: process.env.ETHERSCAN_API_KEY,
    },
    gasReporter: {
        enabled: true,
        currency: "USD",
        token: "ETH",
        coinmarketcap: process.env.CMC_API_KEY,
        excludeContracts: ["testing/"],
        gasPriceApi: "https://api.etherscan.io/api?module=proxy&action=eth_gasPrice",
    },
};
