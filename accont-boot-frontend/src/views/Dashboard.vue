<script setup>
import { onMounted, ref, nextTick, onUnmounted } from 'vue'
import { getAssets, getTransactions } from '@/api'
import * as echarts from 'echarts'

const totalAssets = ref(0)
const monthlyIncome = ref(0)
const monthlyExpense = ref(0)
const assets = ref([])
const recentTransactions = ref([])
const allTransactions = ref([])
const lineChartRef = ref(null)
const pieChartRef = ref(null)
const incomeExpenseChartRef = ref(null)
const topExpenseChartRef = ref(null)
let lineChart = null
let pieChart = null
let incomeExpenseChart = null
let topExpenseChart = null

const themeColorFallbacks = {
    primary: '#c17c4a',
    accentBrown: '#5a4a3f',
    success: '#5a9e78',
    danger: '#d66a5a',
    textMain: '#3d3020',
    textMuted: '#9ca3af',
    paper: '#fefdfb'
}

let themeColors = { ...themeColorFallbacks }

const updateThemeColors = () => {
    if (typeof window === 'undefined') return
    const styles = getComputedStyle(document.documentElement)
    const getVar = (name, fallback) => styles.getPropertyValue(name)?.trim() || fallback

    themeColors = {
        primary: getVar('--accent-gold', themeColorFallbacks.primary),
        accentBrown: getVar('--accent-brown', themeColorFallbacks.accentBrown),
        success: getVar('--el-color-success', themeColorFallbacks.success),
        danger: getVar('--el-color-danger', themeColorFallbacks.danger),
        textMain: getVar('--text-main', themeColorFallbacks.textMain),
        textMuted: getVar('--text-muted', themeColorFallbacks.textMuted),
        paper: getVar('--bg-paper', themeColorFallbacks.paper)
    }
}

const hexToRgba = (hex, alpha = 1) => {
    let sanitized = hex.replace('#', '')
    if (sanitized.length === 3) {
        sanitized = sanitized.split('').map(c => c + c).join('')
    }
    const bigint = parseInt(sanitized, 16)
    const r = (bigint >> 16) & 255
    const g = (bigint >> 8) & 255
    const b = bigint & 255
    return `rgba(${r}, ${g}, ${b}, ${alpha})`
}

const createGradient = (startColor, endColor, horizontal = false) => {
    return new echarts.graphic.LinearGradient(
        0,
        0,
        horizontal ? 1 : 0,
        horizontal ? 0 : 1,
        [
            { offset: 0, color: startColor },
            { offset: 1, color: endColor }
        ]
    )
}

const loadData = async () => {
    try {
        const assetsRes = await getAssets()
        assets.value = assetsRes.data || []
        totalAssets.value = assets.value.reduce((sum, item) => sum + Number(item.balance), 0)

        const transRes = await getTransactions()
        allTransactions.value = transRes.data || []
        recentTransactions.value = allTransactions.value.slice(0, 10)

        calculateMonthlyStats()
        initCharts()
    } catch (error) {
        console.error('Failed to load data:', error)
    }
}

const calculateMonthlyStats = () => {
    const now = new Date()
    const currentMonth = now.getMonth()
    const currentYear = now.getFullYear()

    let income = 0
    let expense = 0

    allTransactions.value.forEach(t => {
        const date = new Date(t.transTime)
        if (date.getMonth() === currentMonth && date.getFullYear() === currentYear) {
            if (t.type === 2) {
                income += Number(t.amount)
            } else if (t.type === 1) {
                expense += Number(t.amount)
            }
        }
    })

    monthlyIncome.value = income
    monthlyExpense.value = expense
}

const getAssetName = (assetId) => {
    const asset = assets.value.find(a => a.id === assetId)
    return asset ? asset.name : '未知账户'
}

const formatMoney = (val) => {
    return Number(val).toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
}

const formatDate = (dateStr) => {
    const date = new Date(dateStr)
    return `${date.getMonth() + 1}月${date.getDate()}日 ${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`
}

const initCharts = async () => {
    await nextTick()
    updateThemeColors()

    if (lineChartRef.value) {
        lineChart = echarts.init(lineChartRef.value)
        renderLineChart()
    }

    if (pieChartRef.value) {
        pieChart = echarts.init(pieChartRef.value)
        renderPieChart()
    }

    if (incomeExpenseChartRef.value) {
        incomeExpenseChart = echarts.init(incomeExpenseChartRef.value)
        renderIncomeExpenseChart()
    }

    if (topExpenseChartRef.value) {
        topExpenseChart = echarts.init(topExpenseChartRef.value)
        renderTopExpenseChart()
    }

    window.addEventListener('resize', handleResize)
}

const handleResize = () => {
    lineChart?.resize()
    pieChart?.resize()
    incomeExpenseChart?.resize()
    topExpenseChart?.resize()
}

const renderLineChart = () => {
    const days = 30
    const dates = []
    let currentBalance = totalAssets.value // This logic assumes totalAssets is CURRENT balance
    // Reconstructing history: Current Balance - (Income - Expense) reverse logic?
    // Balance[t] = Balance[t-1] + Income[t] - Expense[t]
    // So Balance[t-1] = Balance[t] - Income[t] + Expense[t]

    for (let i = 0; i < days; i++) {
        const d = new Date()
        d.setDate(d.getDate() - i)
        dates.unshift(formatLocalDate(d))
    }

    const transMap = {}
    allTransactions.value.forEach(t => {
        const dateStr = formatLocalDate(new Date(t.transTime))
        if (!transMap[dateStr]) transMap[dateStr] = { income: 0, expense: 0 }
        if (t.type === 2) transMap[dateStr].income += Number(t.amount)
        else transMap[dateStr].expense += Number(t.amount)
    })

    const balanceHistory = new Array(days).fill(0)
    balanceHistory[days - 1] = currentBalance

    // We start from yesterday (days - 2) going backwards
    // Today is dates[days-1]. Balance is currentBalance.
    // Yesterday (days-2) Balance = TodayBalance - TodayIncome + TodayExpense
    // Note: If today is partial, we subtract today's transactions to get "start of day" or "yesterday end"?
    // Usually daily trend chart shows "End of Day" balance.
    // So for Today (index d=29), if we have transactions today, currentBalance includes them.
    // To get Yesterday (d=28) End of Day, we remove Today's transactions.

    for (let i = days - 1; i > 0; i--) {
        const dateStr = dates[i]
        const dayTrans = transMap[dateStr] || { income: 0, expense: 0 }
        balanceHistory[i - 1] = balanceHistory[i] - dayTrans.income + dayTrans.expense
    }

    const option = {
        title: { text: '资产趋势 (近30天)', left: 'center', textStyle: { color: themeColors.textMain } },
        tooltip: { trigger: 'axis' },
        grid: { left: '3%', right: '4%', bottom: '3%', containLabel: true },
        xAxis: {
            type: 'category',
            data: dates,
            boundaryGap: false,
            axisLine: { lineStyle: { color: 'rgba(61, 48, 32, 0.2)' } },
            axisLabel: { color: themeColors.textMuted }
        },
        yAxis: {
            type: 'value',
            axisLine: { lineStyle: { color: 'rgba(61, 48, 32, 0.2)' } },
            splitLine: { lineStyle: { color: 'rgba(61, 48, 32, 0.1)' } },
            axisLabel: { color: themeColors.textMuted }
        },
        series: [{
            name: '总资产',
            type: 'line',
            smooth: true,
            data: balanceHistory,
            // Use Primary Gold from theme
            itemStyle: { color: themeColors.primary },
            areaStyle: {
                color: createGradient(
                    hexToRgba(themeColors.primary, 0.45),
                    hexToRgba(themeColors.primary, 0.05)
                )
            }
        }]
    }
    lineChart.setOption(option)
}

const renderPieChart = () => {
    const categoryMap = {}
    allTransactions.value.forEach(t => {
        if (t.type === 1) { // 支出
            if (!categoryMap[t.category]) categoryMap[t.category] = 0
            categoryMap[t.category] += Number(t.amount)
        }
    })

    const data = Object.keys(categoryMap).map(k => ({ value: categoryMap[k], name: k }))

    const option = {
        title: { text: '支出构成', left: 'center' },
        tooltip: { trigger: 'item' },
        legend: { orient: 'horizontal', bottom: 'bottom' },
        series: [{
            name: '支出分类',
            type: 'pie',
            radius: ['40%', '70%'],
            avoidLabelOverlap: false,
            itemStyle: {
                borderRadius: 10,
                borderColor: '#fff',
                borderWidth: 2
            },
            color: ['#c17c4a', '#5a4a3f', '#d66a5a', '#5a9e78', '#8c7b70', '#e0c9b8'],
            label: { show: false, position: 'center' },
            emphasis: {
                label: { show: true, fontSize: 16, fontWeight: 'bold' }
            },
            data: data
        }]
    }
    pieChart.setOption(option)
}

const formatLocalDate = (date) => {
    const year = date.getFullYear()
    const month = String(date.getMonth() + 1).padStart(2, '0')
    const day = String(date.getDate()).padStart(2, '0')
    return `${year}-${month}-${day}`
}

const renderIncomeExpenseChart = () => {
    const days = 7
    const dates = []
    for (let i = 0; i < days; i++) {
        const d = new Date()
        d.setDate(d.getDate() - i)
        dates.unshift(formatLocalDate(d))
    }

    const transMap = {}
    allTransactions.value.forEach(t => {
        const dateStr = formatLocalDate(new Date(t.transTime))
        if (!transMap[dateStr]) transMap[dateStr] = { income: 0, expense: 0 }
        if (t.type === 2) transMap[dateStr].income += Number(t.amount)
        else transMap[dateStr].expense += Number(t.amount)
    })

    const incomeData = dates.map(d => transMap[d]?.income || 0)
    const expenseData = dates.map(d => transMap[d]?.expense || 0)

    const option = {
        title: { text: '收支趋势 (近7天)', left: 'center', textStyle: { color: themeColors.textMain } },
        tooltip: { trigger: 'axis' },
        legend: { bottom: 'bottom', textStyle: { color: themeColors.textMuted } },
        grid: { left: '3%', right: '4%', bottom: '10%', containLabel: true },
        xAxis: {
            type: 'category',
            data: dates,
            axisTick: { show: false },
            axisLine: { lineStyle: { color: 'rgba(61, 48, 32, 0.2)' } },
            axisLabel: { color: themeColors.textMuted }
        },
        yAxis: {
            type: 'value',
            splitLine: { lineStyle: { color: 'rgba(61, 48, 32, 0.1)' } },
            axisLine: { lineStyle: { color: 'rgba(61, 48, 32, 0.2)' } },
            axisLabel: { color: themeColors.textMuted }
        },
        series: [
            {
                name: '收入',
                type: 'bar',
                stack: 'total',
                data: incomeData,
                itemStyle: {
                    color: createGradient(
                        hexToRgba(themeColors.danger, 0.95),
                        hexToRgba(themeColors.danger, 0.35)
                    ),
                    borderRadius: [4, 4, 0, 0]
                },
                emphasis: {
                    itemStyle: {
                        shadowColor: hexToRgba(themeColors.danger, 0.4),
                        shadowBlur: 10
                    }
                }
            },
            {
                name: '支出',
                type: 'bar',
                stack: 'total',
                data: expenseData,
                itemStyle: {
                    color: createGradient(
                        hexToRgba(themeColors.success, 0.9),
                        hexToRgba(themeColors.success, 0.3)
                    ),
                    borderRadius: [4, 4, 0, 0]
                },
                emphasis: {
                    itemStyle: {
                        shadowColor: hexToRgba(themeColors.success, 0.35),
                        shadowBlur: 10
                    }
                }
            }
        ]
    }
    incomeExpenseChart.setOption(option)
}

const renderTopExpenseChart = () => {
    const now = new Date()
    const currentMonth = now.getMonth()
    const currentYear = now.getFullYear()

    const categoryMap = {}
    allTransactions.value.forEach(t => {
        const d = new Date(t.transTime)
        if (d.getMonth() === currentMonth && d.getFullYear() === currentYear && t.type === 1) {
            if (!categoryMap[t.category]) categoryMap[t.category] = 0
            categoryMap[t.category] += Number(t.amount)
        }
    })

    const sorted = Object.entries(categoryMap)
        .sort((a, b) => a[1] - b[1]) // Ascending for bar chart y-axis
        .slice(-5) // Top 5

    const categories = sorted.map(i => i[0])
    const amounts = sorted.map(i => i[1])

    const option = {
        title: { text: '本月支出 Top 5', left: 'center', textStyle: { color: themeColors.textMain } },
        tooltip: { trigger: 'axis', axisPointer: { type: 'shadow' } },
        grid: { left: '3%', right: '4%', bottom: '3%', containLabel: true },
        xAxis: {
            type: 'value',
            splitLine: { lineStyle: { color: 'rgba(61, 48, 32, 0.1)' } },
            axisLabel: { color: themeColors.textMuted }
        },
        yAxis: {
            type: 'category',
            data: categories,
            axisLine: { show: false },
            axisTick: { show: false },
            axisLabel: { color: themeColors.textMain }
        },
        series: [
            {
                name: '支出',
                type: 'bar',
                data: amounts,
                itemStyle: {
                    color: themeColors.primary,
                    borderRadius: [0, 8, 8, 0],
                    shadowColor: hexToRgba(themeColors.primary, 0.2),
                    shadowBlur: 8
                },
                label: { show: true, position: 'right', color: themeColors.textMain }
            }
        ]
    }
    topExpenseChart.setOption(option)
}

onMounted(() => {
    loadData()
})

onUnmounted(() => {
    window.removeEventListener('resize', handleResize)
    lineChart?.dispose()
    pieChart?.dispose()
    incomeExpenseChart?.dispose()
    topExpenseChart?.dispose()
})
</script>

<template>
    <div class="dashboard animate-in">
        <!-- 顶部统计卡片 -->
        <el-row :gutter="24" class="stat-row">
            <el-col :xs="24" :sm="8">
                <div class="stat-card primary">
                    <div class="stat-icon">
                        <el-icon :size="40">
                            <Wallet />
                        </el-icon>
                    </div>
                    <div class="stat-content">
                        <div class="stat-value">¥{{ formatMoney(totalAssets) }}</div>
                        <div class="stat-label">总资产</div>
                    </div>
                </div>
            </el-col>
            <el-col :xs="24" :sm="8">
                <!-- Income: Positive/Up => Red (Success color swapped to Red in main.css/variables) -->
                <!-- Or wait, if we swapped global 'success' to Red, then using 'success' class here gives Red. -->
                <div class="stat-card success">
                    <div class="stat-icon">
                        <el-icon :size="40">
                            <TrendCharts />
                        </el-icon>
                    </div>
                    <div class="stat-content">
                        <div class="stat-value">+{{ formatMoney(monthlyIncome) }}</div>
                        <div class="stat-label">本月收入</div>
                    </div>
                </div>
            </el-col>
            <el-col :xs="24" :sm="8">
                <!-- Expense: Negative/Down => Green (Danger color swapped to Green in main.css) -->
                <div class="stat-card danger">
                    <div class="stat-icon">
                        <el-icon :size="40">
                            <ShoppingCart />
                        </el-icon>
                    </div>
                    <div class="stat-content">
                        <div class="stat-value">-{{ formatMoney(monthlyExpense) }}</div>
                        <div class="stat-label">本月支出</div>
                    </div>
                </div>
            </el-col>
        </el-row>

        <!-- 图表区域 -->
        <el-row :gutter="24" class="chart-row">
            <el-col :xs="24" :lg="16">
                <div class="content-card">
                    <div class="chart-container" ref="lineChartRef"></div>
                </div>
            </el-col>
            <el-col :xs="24" :lg="8">
                <div class="content-card">
                    <div class="chart-container" ref="pieChartRef"></div>
                </div>
            </el-col>
        </el-row>

        <!-- 新增图表区域 -->
        <el-row :gutter="24" class="chart-row">
            <el-col :xs="24" :lg="12">
                <div class="content-card">
                    <div class="chart-container" ref="incomeExpenseChartRef"></div>
                </div>
            </el-col>
            <el-col :xs="24" :lg="12">
                <div class="content-card">
                    <div class="chart-container" ref="topExpenseChartRef"></div>
                </div>
            </el-col>
        </el-row>

        <!-- 资产和流水 -->
        <el-row :gutter="24" class="content-row">
            <!-- 资产概览 -->
            <el-col :xs="24" :lg="8">
                <div class="content-card">
                    <div class="card-header">
                        <span class="card-title">资产概览</span>
                        <router-link to="/assets">
                            <el-button type="primary" link>查看全部</el-button>
                        </router-link>
                    </div>
                    <div class="card-body">
                        <div v-if="assets.length === 0" class="empty-state">
                            <el-icon>
                                <Wallet />
                            </el-icon>
                            <p>暂无资产账户</p>
                        </div>
                        <div v-else class="asset-list">
                            <div v-for="asset in assets" :key="asset.id" class="asset-item"
                                @click="$router.push('/assets')">
                                <div class="asset-info">
                                    <div class="asset-icon">
                                        <el-icon>
                                            <CreditCard />
                                        </el-icon>
                                    </div>
                                    <span class="asset-name">{{ asset.name }}</span>
                                </div>
                                <span class="amount">¥{{ formatMoney(asset.balance) }}</span>
                            </div>
                        </div>
                    </div>
                </div>
            </el-col>

            <!-- 近期流水 -->
            <el-col :xs="24" :lg="16">
                <div class="content-card">
                    <div class="card-header">
                        <span class="card-title">近期流水</span>
                        <router-link to="/transactions">
                            <el-button type="primary" link>查看全部</el-button>
                        </router-link>
                    </div>
                    <div class="card-body">
                        <div v-if="recentTransactions.length === 0" class="empty-state">
                            <el-icon>
                                <List />
                            </el-icon>
                            <p>暂无交易记录</p>
                        </div>
                        <el-table v-else :data="recentTransactions" style="width: 100%">
                            <el-table-column prop="category" label="分类" width="120">
                                <template #default="{ row }">
                                    <span class="tag" :class="row.type === 1 ? 'expense' : 'income'">
                                        {{ row.category }}
                                    </span>
                                </template>
                            </el-table-column>
                            <el-table-column label="账户" width="120">
                                <template #default="{ row }">
                                    {{ getAssetName(row.assetId) }}
                                </template>
                            </el-table-column>
                            <el-table-column label="金额" align="right">
                                <template #default="{ row }">
                                    <span class="amount" :class="row.type === 1 ? 'expense' : 'income'">
                                        {{ row.type === 1 ? '-' : '+' }}¥{{ formatMoney(row.amount) }}
                                    </span>
                                </template>
                            </el-table-column>
                            <el-table-column label="时间" align="right" width="150">
                                <template #default="{ row }">
                                    <span class="time-text">{{ formatDate(row.transTime) }}</span>
                                </template>
                            </el-table-column>
                        </el-table>
                    </div>
                </div>
            </el-col>
        </el-row>
    </div>
</template>

<style scoped>
.dashboard {
    min-height: 100%;
}

.stat-row {
    margin-bottom: 24px;
}

/* Removed conflicting stat-card styles to use global main.css styles */

.chart-row {
    margin-bottom: 24px;
}

.chart-container {
    width: 100%;
    height: 350px;
}

.content-row .el-col {
    margin-bottom: 24px;
}

.asset-list {
    display: flex;
    flex-direction: column;
    gap: 16px;
}

.asset-item {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 12px 16px;
    background: #fdfbf7;
    /* Match paper theme */
    border: 1px solid #f0eae6;
    border-radius: 12px;
    transition: all 0.3s ease;
    cursor: pointer;
}

.asset-item:hover {
    background: #fff;
    border-color: var(--accent-gold);
    transform: translateX(4px);
    box-shadow: 0 4px 12px rgba(90, 74, 63, 0.05);
}

.asset-info {
    display: flex;
    align-items: center;
    gap: 12px;
}

.asset-icon {
    width: 40px;
    height: 40px;
    display: flex;
    align-items: center;
    justify-content: center;
    background: rgba(193, 124, 74, 0.1);
    /* Gold tint */
    color: var(--accent-gold);
    border-radius: 10px;
}

.asset-name {
    font-weight: 500;
    color: var(--text-main);
}

.time-text {
    color: var(--text-muted);
    font-size: 13px;
}

@media (max-width: 768px) {

    /* Adjusted for global styles */
    .stat-card {
        margin-bottom: 16px;
    }
}
</style>
