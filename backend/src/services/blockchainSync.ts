import { createPublicClient, createWalletClient, http, parseAbiItem } from 'viem';
import { foundry } from 'viem/chains';
import { DatabaseService } from './database';
import { logger } from '../utils/logger';

// 合约 ABI 片段
const EVENT_CREATED_ABI = parseAbiItem('event EventCreated(uint256 indexed eventId, address indexed organizer, string name, uint256 maxTickets, uint256 ticketPrice)');
const TICKET_MINTED_ABI = parseAbiItem('event TicketMinted(uint256 indexed tokenId, uint256 indexed eventId, address indexed to, string seatNumber)');
const TICKET_TRANSFERRED_ABI = parseAbiItem('event Transfer(address indexed from, address indexed to, uint256 indexed tokenId)');
const ORDER_CREATED_ABI = parseAbiItem('event OrderCreated(bytes32 indexed orderId, address indexed buyer, uint256 indexed eventId, uint256 price)');

export class BlockchainSyncService {
  private publicClient;
  private isRunning = false;
  private syncInterval: NodeJS.Timeout | null = null;

  constructor() {
    this.publicClient = createPublicClient({
      chain: foundry,
      transport: http(process.env.RPC_URL || 'http://localhost:8545')
    });
  }

  async start(): Promise<void> {
    if (this.isRunning) return;

    this.isRunning = true;
    logger.info('启动区块链同步服务');

    // 立即执行一次同步
    await this.syncAllContracts();

    // 设置定时同步 (每30秒)
    this.syncInterval = setInterval(async () => {
      try {
        await this.syncAllContracts();
      } catch (error) {
        logger.error('区块链同步失败:', error);
      }
    }, 30000);
  }

  async stop(): Promise<void> {
    this.isRunning = false;
    if (this.syncInterval) {
      clearInterval(this.syncInterval);
      this.syncInterval = null;
    }
    logger.info('区块链同步服务已停止');
  }

  private async syncAllContracts(): Promise<void> {
    const contracts = [
      { name: 'EventManager', address: process.env.EVENT_MANAGER_ADDRESS },
      { name: 'TicketManager', address: process.env.TICKET_MANAGER_ADDRESS },
      { name: 'Marketplace', address: process.env.MARKETPLACE_ADDRESS },
      { name: 'TokenSwap', address: process.env.TOKEN_SWAP_ADDRESS }
    ];

    for (const contract of contracts) {
      if (contract.address) {
        await this.syncContract(contract.address, contract.name);
      }
    }
  }

  private async syncContract(contractAddress: string, contractName: string): Promise<void> {
    try {
      const db = DatabaseService.getInstance();

      // 获取上次同步的区块号
      let syncRecord = await db.blockchainSync.findUnique({
        where: { contractAddress }
      });

      const fromBlock = syncRecord?.lastBlockNumber
        ? syncRecord.lastBlockNumber + BigInt(1)
        : BigInt(0);

      const currentBlock = await this.publicClient.getBlockNumber();

      if (fromBlock > currentBlock) return;

      logger.debug(`同步合约 ${contractName} 从区块 ${fromBlock} 到 ${currentBlock}`);

      // 根据合约类型同步不同的事件
      switch (contractName) {
        case 'EventManager':
          await this.syncEventManagerEvents(contractAddress, fromBlock, currentBlock);
          break;
        case 'TicketManager':
          await this.syncTicketManagerEvents(contractAddress, fromBlock, currentBlock);
          break;
        case 'Marketplace':
          await this.syncMarketplaceEvents(contractAddress, fromBlock, currentBlock);
          break;
        default:
          logger.warn(`未知的合约类型: ${contractName}`);
      }

      // 更新同步记录
      await db.blockchainSync.upsert({
        where: { contractAddress },
        update: {
          lastBlockNumber: currentBlock,
          syncedAt: new Date()
        },
        create: {
          contractAddress,
          lastBlockNumber: currentBlock,
          syncedAt: new Date()
        }
      });

    } catch (error) {
      logger.error(`同步合约 ${contractName} 失败:`, error);
    }
  }

  private async syncEventManagerEvents(
    contractAddress: string,
    fromBlock: bigint,
    toBlock: bigint
  ): Promise<void> {
    const logs = await this.publicClient.getLogs({
      address: contractAddress as `0x${string}`,
      event: EVENT_CREATED_ABI,
      fromBlock,
      toBlock
    });

    const db = DatabaseService.getInstance();

    for (const log of logs) {
      try {
        const { eventId, organizer, name, maxTickets, ticketPrice } = log.args;

        // 检查事件是否已存在
        const existingEvent = await db.event.findUnique({
          where: {
            chainId_contractId: {
              chainId: foundry.id,
              contractId: eventId.toString()
            }
          }
        });

        if (!existingEvent) {
          // 确保组织者用户存在
          await db.user.upsert({
            where: { address: organizer.toLowerCase() },
            update: {},
            create: { address: organizer.toLowerCase() }
          });

          // 创建新事件记录
          await db.event.create({
            data: {
              chainId: foundry.id,
              contractId: eventId.toString(),
              name,
              maxTickets: Number(maxTickets),
              ticketPrice: ticketPrice.toString(),
              organizer: {
                connect: { address: organizer.toLowerCase() }
              },
              // 设置默认值，实际值需要从链上或其他来源获取
              startTime: new Date(),
              endTime: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000) // 7天后
            }
          });

          logger.info(`新建事件: ${name} (ID: ${eventId})`);
        }
      } catch (error) {
        logger.error('处理 EventCreated 事件失败:', error);
      }
    }
  }

  private async syncTicketManagerEvents(
    contractAddress: string,
    fromBlock: bigint,
    toBlock: bigint
  ): Promise<void> {
    // 同步门票铸造事件
    const mintLogs = await this.publicClient.getLogs({
      address: contractAddress as `0x${string}`,
      event: TICKET_MINTED_ABI,
      fromBlock,
      toBlock
    });

    // 同步转移事件
    const transferLogs = await this.publicClient.getLogs({
      address: contractAddress as `0x${string}`,
      event: TICKET_TRANSFERRED_ABI,
      fromBlock,
      toBlock
    });

    const db = DatabaseService.getInstance();

    // 处理铸造事件
    for (const log of mintLogs) {
      try {
        const { tokenId, eventId, to, seatNumber } = log.args;

        // 确保用户存在
        await db.user.upsert({
          where: { address: to.toLowerCase() },
          update: {},
          create: { address: to.toLowerCase() }
        });

        // 检查门票是否已存在
        const existingTicket = await db.ticket.findUnique({
          where: {
            chainId_tokenId: {
              chainId: foundry.id,
              tokenId: tokenId.toString()
            }
          }
        });

        if (!existingTicket) {
          // 查找对应的事件
          const event = await db.event.findUnique({
            where: {
              chainId_contractId: {
                chainId: foundry.id,
                contractId: eventId.toString()
              }
            }
          });

          if (event) {
            await db.ticket.create({
              data: {
                chainId: foundry.id,
                tokenId: tokenId.toString(),
                eventId: event.id,
                seatNumber,
                owner: {
                  connect: { address: to.toLowerCase() }
                }
              }
            });

            logger.info(`新建门票: Token ${tokenId} for Event ${eventId}`);
          }
        }
      } catch (error) {
        logger.error('处理 TicketMinted 事件失败:', error);
      }
    }

    // 处理转移事件
    for (const log of transferLogs) {
      try {
        const { from, to, tokenId } = log.args;

        // 跳过铸造交易 (from = 0x0)
        if (from === '0x0000000000000000000000000000000000000000') continue;

        // 确保新拥有者存在
        await db.user.upsert({
          where: { address: to.toLowerCase() },
          update: {},
          create: { address: to.toLowerCase() }
        });

        // 更新门票拥有者
        await db.ticket.updateMany({
          where: {
            chainId: foundry.id,
            tokenId: tokenId.toString()
          },
          data: {
            ownerId: to.toLowerCase()
          }
        });

        logger.info(`门票转移: Token ${tokenId} from ${from} to ${to}`);
      } catch (error) {
        logger.error('处理 Transfer 事件失败:', error);
      }
    }
  }

  private async syncMarketplaceEvents(
    contractAddress: string,
    fromBlock: bigint,
    toBlock: bigint
  ): Promise<void> {
    const logs = await this.publicClient.getLogs({
      address: contractAddress as `0x${string}`,
      event: ORDER_CREATED_ABI,
      fromBlock,
      toBlock
    });

    const db = DatabaseService.getInstance();

    for (const log of logs) {
      try {
        const { orderId, buyer, eventId, price } = log.args;

        // 确保买家用户存在
        await db.user.upsert({
          where: { address: buyer.toLowerCase() },
          update: {},
          create: { address: buyer.toLowerCase() }
        });

        // 查找对应的事件
        const event = await db.event.findUnique({
          where: {
            chainId_contractId: {
              chainId: foundry.id,
              contractId: eventId.toString()
            }
          }
        });

        if (event) {
          // 检查订单是否已存在
          const existingOrder = await db.order.findFirst({
            where: {
              chainId: foundry.id,
              transactionHash: log.transactionHash
            }
          });

          if (!existingOrder) {
            await db.order.create({
              data: {
                chainId: foundry.id,
                transactionHash: log.transactionHash,
                orderType: 'PRIMARY',
                status: 'CONFIRMED',
                price: price.toString(),
                paymentToken: '0x0000000000000000000000000000000000000000', // ETH
                buyer: {
                  connect: { address: buyer.toLowerCase() }
                },
                event: {
                  connect: { id: event.id }
                }
              }
            });

            logger.info(`新建订单: ${orderId} for Event ${eventId}`);
          }
        }
      } catch (error) {
        logger.error('处理 OrderCreated 事件失败:', error);
      }
    }
  }
}
