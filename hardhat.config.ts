import '@nomiclabs/hardhat-ethers';
import '@nomiclabs/hardhat-etherscan';
import '@primitivefi/hardhat-dodoc';
import '@typechain/hardhat';
import 'dotenv/config';
import 'hardhat-contract-sizer';
import 'hardhat-deploy';
import 'hardhat-gas-reporter';
import 'hardhat-interface-generator';
import 'hardhat-tracer';
import {HardhatUserConfig} from 'hardhat/types';
import 'solidity-coverage';
import {accounts, node_url} from './utils/network';

if (process.env.HARDHAT_FORK) {
  process.env['HARDHAT_DEPLOY_FORK'] = process.env.HARDHAT_FORK;
}

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: '0.8.17',
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
          evmVersion: 'istanbul',
        },
      },
    ],
  },

  namedAccounts: {
    deployer: {
      default: 0,
      1: process.env.MAINNET_DEPLOYER ?? '',
    },
    governance: {
      default: 1,
    },
    contractee: {
      default: 2,
    },
    contractor: {
      default: 3,
    },
    user1: {
      default: 4,
    },
  },

  networks: {
    hardhat: {
      // fix issues where waffle is not using the correct chainId
      chainId: 1337,
      // process.env.HARDHAT_FORK will specify the network that the fork is made from.
      // this line ensure the use of the corresponding accounts
      accounts: accounts(process.env.HARDHAT_FORK),
      forking: process.env.HARDHAT_FORK
        ? {
            url: node_url(process.env.HARDHAT_FORK),
            blockNumber: process.env.HARDHAT_FORK_NUMBER
              ? parseInt(process.env.HARDHAT_FORK_NUMBER)
              : undefined,
          }
        : undefined,
      saveDeployments: true,
      tags: ['test', 'local'],
    },
    localhost: {
      url: node_url('localhost'),
      accounts: accounts(),
      tags: ['local', 'test'],
    },
    ganache: {
      url: node_url('ganache'),
      accounts: accounts(),
      tags: ['local', 'test'],
    },
    mainnet: {
      url: node_url('mainnet'),
      accounts: accounts('mainnet'),
      tags: ['production'],
    },
    polygon: {
      url: node_url('polygon'),
      accounts: accounts('polygon'),
      tags: ['production'],
    },
    rinkeby: {
      url: node_url('rinkeby'),
      accounts: accounts('rinkeby'),
      tags: ['test', 'staging'],
    },
    kovan: {
      url: node_url('kovan'),
      accounts: accounts('kovan'),
      tags: ['test', 'staging'],
    },
    goerli: {
      url: node_url('goerli'),
      accounts: accounts('goerli'),
      tags: ['test', 'staging'],
    },
    mumbai: {
      url: node_url('mumbai'),
      accounts: accounts('mumbai'),
      tags: ['test', 'staging'],
      verify: {
        etherscan: {
          apiKey: process.env.POLYGONSCAN_KEY,
        },
      },
    },
    arbitrum: {
      url: node_url('arbitrum'),
      accounts: accounts('arbitrum'),
      tags: ['production'],
    },
  },
  paths: {
    sources: 'src',
    cache: 'hh-cache',
  },
  gasReporter: {
    currency: 'USD',
    gasPrice: 100,
    enabled: process.env.REPORT_GAS ? true : false,
    coinmarketcap: process.env.COINMARKETCAP_API_KEY,
    maxMethodDiff: 10,
  },
  typechain: {
    outDir: 'typechain',
    target: 'ethers-v5',
  },
  mocha: {
    timeout: 0,
  },
  verify: {
    etherscan: {
      // Your API key for Etherscan
      // Obtain one at https://etherscan.io/
      apiKey: process.env.ETHERSCAN_KEY ?? '',
    },
  },
  dodoc: {},
};

export default config;
