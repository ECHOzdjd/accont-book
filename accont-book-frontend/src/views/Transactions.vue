<script setup>
import { ref, computed, onMounted } from 'vue'
import { ElMessageBox, ElMessage } from 'element-plus'
import { getTransactions, getAssets, addTransaction, deleteTransaction } from '@/api'

const transactions = ref([])
const assets = ref([])
const loading = ref(true)
const dialogVisible = ref(false)

const form = ref({
    assetId: null,
    type: 1,
    category: '',
    amount: null,
    transTime: new Date()
})

// 常用分类
const expenseCategories = ['餐饮', '交通', '购物', '娱乐', '居住', '通讯', '医疗', '教育', '其他']
const incomeCategories = ['工资', '奖金', '理财', '红包', '退款', '其他']

const currentCategories = computed(() => {
    return form.value.type === 1 ? expenseCategories : incomeCategories
})

// 格式化金额
const formatMoney = (val) => {
    return Number(val).toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
}

// 格式化日期
const formatDate = (dateStr) => {
    const date = new Date(dateStr)
    const year = date.getFullYear()
    const month = String(date.getMonth() + 1).padStart(2, '0')
    const day = String(date.getDate()).padStart(2, '0')
    const hour = String(date.getHours()).padStart(2, '0')
    const min = String(date.getMinutes()).padStart(2, '0')
    return `${year}-${month}-${day} ${hour}:${min}`
}

// 获取资产名称
const getAssetName = (assetId) => {
    const asset = assets.value.find(a => a.id === assetId)
    return asset ? asset.name : '未知账户'
}

// 加载数据
const loadData = async () => {
    loading.value = true
    try {
        const [transRes, assetRes] = await Promise.all([
            getTransactions(),
            getAssets()
        ])
        transactions.value = (transRes.data || []).sort((a, b) => new Date(b.transTime) - new Date(a.transTime))
        assets.value = assetRes.data || []
    } catch (e) {
        console.error('加载数据失败', e)
    } finally {
        loading.value = false
    }
}

// 打开记账对话框
const openDialog = () => {
    form.value = {
        assetId: assets.value.length > 0 ? assets.value[0].id : null,
        type: 1,
        category: '',
        amount: null,
        transTime: new Date()
    }
    dialogVisible.value = true
}

// 提交记账
const submitTransaction = async () => {
    if (!form.value.assetId) {
        ElMessage.warning('请选择账户')
        return
    }
    if (!form.value.category) {
        ElMessage.warning('请选择分类')
        return
    }
    if (!form.value.amount || form.value.amount <= 0) {
        ElMessage.warning('请输入有效金额')
        return
    }

    try {
        await addTransaction({
            assetId: form.value.assetId,
            type: form.value.type,
            category: form.value.category,
            amount: form.value.amount,
            transTime: form.value.transTime
        })
        ElMessage.success('记账成功')
        dialogVisible.value = false
        loadData()
    } catch (e) {
        console.error('记账失败', e)
    }
}

// 删除流水
const handleDelete = async (trans) => {
    try {
        await ElMessageBox.confirm(
            `确定要删除这笔${trans.type === 1 ? '支出' : '收入'}记录吗？删除后余额将自动回滚。`,
            '删除确认',
            { confirmButtonText: '删除', cancelButtonText: '取消', type: 'warning' }
        )
        await deleteTransaction(trans.id)
        ElMessage.success('删除成功')
        loadData()
    } catch (e) {
        if (e !== 'cancel') {
            console.error('删除失败', e)
        }
    }
}

onMounted(loadData)
</script>

<template>
    <div class="transactions-page" v-loading="loading">
        <!-- 操作栏 -->
        <div class="action-bar animate-in">
            <el-button type="primary" size="large" @click="openDialog">
                <el-icon>
                    <Plus />
                </el-icon>
                记一笔
            </el-button>
        </div>

        <!-- 流水列表 -->
        <div class="content-card animate-in" style="animation-delay: 0.1s">
            <div class="card-header">
                <span class="card-title">全部流水</span>
                <span class="card-count">共 {{ transactions.length }} 条</span>
            </div>
            <div class="card-body" style="padding: 0">
                <div v-if="transactions.length === 0" class="empty-state">
                    <el-icon>
                        <List />
                    </el-icon>
                    <p>暂无交易记录，点击上方按钮开始记账</p>
                </div>
                <el-table v-else :data="transactions" style="width: 100%" row-class-name="trans-row">
                    <el-table-column label="类型" width="100">
                        <template #default="{ row }">
                            <span class="tag" :class="row.type === 1 ? 'expense' : 'income'">
                                {{ row.type === 1 ? '支出' : '收入' }}
                            </span>
                        </template>
                    </el-table-column>
                    <el-table-column prop="category" label="分类" width="120">
                        <template #default="{ row }">
                            <span class="category-text">{{ row.category }}</span>
                        </template>
                    </el-table-column>
                    <el-table-column label="账户" width="140">
                        <template #default="{ row }">
                            <div class="account-cell">
                                <el-icon>
                                    <CreditCard />
                                </el-icon>
                                {{ getAssetName(row.assetId) }}
                            </div>
                        </template>
                    </el-table-column>
                    <el-table-column label="金额" width="150">
                        <template #default="{ row }">
                            <span class="amount" :class="row.type === 1 ? 'expense' : 'income'">
                                {{ row.type === 1 ? '-' : '+' }}¥{{ formatMoney(row.amount) }}
                            </span>
                        </template>
                    </el-table-column>
                    <el-table-column label="时间" min-width="180">
                        <template #default="{ row }">
                            <span class="time-text">{{ formatDate(row.transTime) }}</span>
                        </template>
                    </el-table-column>
                    <el-table-column label="操作" width="100" fixed="right">
                        <template #default="{ row }">
                            <el-button type="danger" link @click="handleDelete(row)">
                                <el-icon>
                                    <Delete />
                                </el-icon>
                            </el-button>
                        </template>
                    </el-table-column>
                </el-table>
            </div>
        </div>

        <!-- 记账对话框 -->
        <el-dialog v-model="dialogVisible" title="记一笔" width="450px">
            <el-form :model="form" label-width="80px" class="trans-form">
                <!-- 收支类型 -->
                <el-form-item label="类型">
                    <el-radio-group v-model="form.type" class="type-radio">
                        <el-radio-button :value="1">
                            <el-icon>
                                <Minus />
                            </el-icon> 支出
                        </el-radio-button>
                        <el-radio-button :value="2">
                            <el-icon>
                                <Plus />
                            </el-icon> 收入
                        </el-radio-button>
                    </el-radio-group>
                </el-form-item>

                <!-- 账户选择 -->
                <el-form-item label="账户" required>
                    <el-select v-model="form.assetId" placeholder="请选择账户" style="width: 100%">
                        <el-option v-for="asset in assets" :key="asset.id" :label="asset.name" :value="asset.id" />
                    </el-select>
                </el-form-item>

                <!-- 分类选择 -->
                <el-form-item label="分类" required>
                    <div class="category-grid">
                        <div v-for="cat in currentCategories" :key="cat" class="category-item"
                            :class="{ active: form.category === cat }" @click="form.category = cat">
                            {{ cat }}
                        </div>
                    </div>
                </el-form-item>

                <!-- 金额 -->
                <el-form-item label="金额" required>
                    <el-input-number v-model="form.amount" :min="0.01" :precision="2" placeholder="请输入金额"
                        style="width: 100%" />
                </el-form-item>

                <!-- 时间 -->
                <el-form-item label="时间">
                    <el-date-picker v-model="form.transTime" type="datetime" placeholder="选择时间" style="width: 100%" />
                </el-form-item>
            </el-form>

            <template #footer>
                <el-button @click="dialogVisible = false">取消</el-button>
                <el-button type="primary" @click="submitTransaction">确认记账</el-button>
            </template>
        </el-dialog>
    </div>
</template>

<style scoped>
.transactions-page {
    min-height: 100%;
}

.action-bar {
    margin-bottom: 24px;
}

.card-count {
    font-size: 14px;
    color: var(--text-muted);
}

.category-text {
    font-weight: 500;
}

.account-cell {
    display: flex;
    align-items: center;
    gap: 6px;
    color: var(--text-secondary);
}

.time-text {
    color: var(--text-secondary);
    font-size: 13px;
}

.empty-state {
    padding: 60px 20px;
}

/* 表单样式 */
.trans-form {
    padding: 10px 0;
}

.type-radio {
    width: 100%;
}

.type-radio .el-radio-button {
    width: 50%;
}

.type-radio .el-radio-button__inner {
    width: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 6px;
}

.category-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 10px;
}

.category-item {
    padding: 10px 16px;
    background: #f1f5f9;
    border-radius: 8px;
    text-align: center;
    cursor: pointer;
    transition: all 0.2s ease;
    font-size: 14px;
}

.category-item:hover {
    background: #e2e8f0;
}

.category-item.active {
    background: var(--accent-gold);
    color: #fff;
}

/* 表格行样式 */
:deep(.trans-row) {
    transition: background-color 0.2s;
}

:deep(.trans-row:hover) {
    background-color: #fdfbf7;
}
</style>
