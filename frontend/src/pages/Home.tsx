export function Home() {
  return (
    <div className="container mx-auto px-4 py-8">
      <div className="text-center">
        <h1 className="text-4xl font-bold mb-4">OnlineTicket</h1>
        <p className="text-xl text-muted-foreground mb-8">
          基于区块链的去中心化门票管理平台
        </p>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mt-12">
          <div className="p-6 rounded-lg border">
            <h3 className="text-lg font-semibold mb-2">安全透明</h3>
            <p className="text-muted-foreground">
              基于区块链技术，防伪造、防篡改
            </p>
          </div>

          <div className="p-6 rounded-lg border">
            <h3 className="text-lg font-semibold mb-2">二级市场</h3>
            <p className="text-muted-foreground">
              支持门票安全转让与交易
            </p>
          </div>

          <div className="p-6 rounded-lg border">
            <h3 className="text-lg font-semibold mb-2">代币经济</h3>
            <p className="text-muted-foreground">
              平台代币支付，享受更多优惠
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
