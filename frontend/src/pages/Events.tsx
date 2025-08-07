export function Events() {
  return (
    <div className="container mx-auto px-4 py-8">
      <h1 className="text-3xl font-bold mb-8">活动列表</h1>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {/* 示例活动卡片 */}
        <div className="border rounded-lg overflow-hidden shadow-sm hover:shadow-md transition-shadow">
          <div className="h-48 bg-gradient-to-r from-blue-500 to-purple-600"></div>
          <div className="p-6">
            <h3 className="text-xl font-semibold mb-2">音乐节 2025</h3>
            <p className="text-muted-foreground mb-4">
              一年一度的盛大音乐节，汇聚全球顶级艺人
            </p>
            <div className="flex justify-between items-center text-sm text-muted-foreground mb-4">
              <span>📅 2025-08-15</span>
              <span>📍 上海体育场</span>
            </div>
            <div className="flex justify-between items-center">
              <span className="text-lg font-bold">¥299 起</span>
              <button className="bg-blue-500 hover:bg-blue-600 text-white px-4 py-2 rounded transition-colors">
                查看详情
              </button>
            </div>
          </div>
        </div>

        <div className="border rounded-lg overflow-hidden shadow-sm hover:shadow-md transition-shadow">
          <div className="h-48 bg-gradient-to-r from-green-500 to-teal-600"></div>
          <div className="p-6">
            <h3 className="text-xl font-semibold mb-2">科技大会</h3>
            <p className="text-muted-foreground mb-4">
              探索未来科技趋势，与行业领袖面对面交流
            </p>
            <div className="flex justify-between items-center text-sm text-muted-foreground mb-4">
              <span>📅 2025-09-20</span>
              <span>📍 深圳会展中心</span>
            </div>
            <div className="flex justify-between items-center">
              <span className="text-lg font-bold">¥599 起</span>
              <button className="bg-green-500 hover:bg-green-600 text-white px-4 py-2 rounded transition-colors">
                查看详情
              </button>
            </div>
          </div>
        </div>

        <div className="border rounded-lg overflow-hidden shadow-sm hover:shadow-md transition-shadow">
          <div className="h-48 bg-gradient-to-r from-red-500 to-pink-600"></div>
          <div className="p-6">
            <h3 className="text-xl font-semibold mb-2">戏剧表演</h3>
            <p className="text-muted-foreground mb-4">
              经典话剧重现，感受艺术的魅力与力量
            </p>
            <div className="flex justify-between items-center text-sm text-muted-foreground mb-4">
              <span>📅 2025-10-10</span>
              <span>📍 北京人艺剧场</span>
            </div>
            <div className="flex justify-between items-center">
              <span className="text-lg font-bold">¥188 起</span>
              <button className="bg-red-500 hover:bg-red-600 text-white px-4 py-2 rounded transition-colors">
                查看详情
              </button>
            </div>
          </div>
        </div>
      </div>

      <div className="mt-12 text-center">
        <button className="bg-gray-100 hover:bg-gray-200 text-gray-800 px-6 py-3 rounded-lg transition-colors">
          加载更多活动
        </button>
      </div>
    </div>
  )
}
