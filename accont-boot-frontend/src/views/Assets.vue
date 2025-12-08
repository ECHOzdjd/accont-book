<script setup>
import { ref, onMounted } from 'vue'
import { ElMessageBox, ElMessage } from 'element-plus'
import { getAssets, createAsset, updateAsset, deleteAsset } from '@/api'

const assets = ref([])
const loading = ref(true)
const dialogVisible = ref(false)
const dialogType = ref('add') // add | edit
const editingAsset = ref(null)

const form = ref({
    name: '',
    balance: 0
})

// 格式化金额
const formatMoney = (val) => {
    return Number(val).toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
}

// 加载资产列表
const loadAssets = async () => {
    loading.value = true
    try {
        const res = await getAssets()
        assets.value = res.data || []
    } catch (e) {
        console.error('加载资产失败', e)
    } finally {
        loading.value = false
    }
}

// 打开新增对话框
const openAddDialog = () => {
    dialogType.value = 'add'
    form.value = { name: '', balance: 0 }
    dialogVisible.value = true
}

// 打开编辑对话框
const openEditDialog = (asset) => {
    dialogType.value = 'edit'
    editingAsset.value = asset
    form.value = { name: asset.name, balance: asset.balance }
    dialogVisible.value = true
}

// 保存资产
const saveAsset = async () => {
    if (!form.value.name.trim()) {
        ElMessage.warning('请输入账户名称')
        return
    }

    try {
        if (dialogType.value === 'add') {
            await createAsset(form.value)
            ElMessage.success('创建成功')
        } else {
            await updateAsset(editingAsset.value.id, form.value.name)
            ElMessage.success('更新成功')
        }
        dialogVisible.value = false
        loadAssets()
    } catch (e) {
        console.error('保存失败', e)
    }
}

// 删除资产
const handleDelete = async (asset) => {
    try {
        await ElMessageBox.confirm(
            `确定要删除账户"${asset.name}"吗？只有无流水记录的账户才能删除。`,
            '删除确认',
            { confirmButtonText: '删除', cancelButtonText: '取消', type: 'warning' }
        )
        await deleteAsset(asset.id)
        ElMessage.success('删除成功')
        loadAssets()
    } catch (e) {
        if (e !== 'cancel') {
            console.error('删除失败', e)
        }
    }
}

onMounted(loadAssets)
</script>

<template>
    <div class="assets-page" v-loading="loading">
        <!-- 操作栏 -->
        <div class="action-bar animate-in">
            <el-button type="primary" @click="openAddDialog">
                <el-icon>
                    <Plus />
                </el-icon>
                新增账户
            </el-button>
        </div>

        <!-- 资产卡片网格 -->
        <div v-if="assets.length === 0 && !loading" class="empty-state animate-in">
            <el-icon>
                <Wallet />
            </el-icon>
            <p>暂无资产账户，点击上方按钮添加</p>
        </div>

        <el-row :gutter="24" v-else>
            <el-col :xs="24" :sm="12" :lg="8" :xl="6" v-for="(asset, index) in assets" :key="asset.id">
                <div class="asset-card animate-in" :style="{ animationDelay: `${0.1 * index}s` }">
                    <div class="asset-card-header">
                        <div class="asset-icon">
                            <el-icon :size="28">
                                <CreditCard />
                            </el-icon>
                        </div>
                        <el-dropdown @command="(cmd) => cmd === 'edit' ? openEditDialog(asset) : handleDelete(asset)">
                            <el-button type="info" link>
                                <el-icon>
                                    <MoreFilled />
                                </el-icon>
                            </el-button>
                            <template #dropdown>
                                <el-dropdown-menu>
                                    <el-dropdown-item command="edit">
                                        <el-icon>
                                            <Edit />
                                        </el-icon> 编辑
                                    </el-dropdown-item>
                                    <el-dropdown-item command="delete" divided>
                                        <el-icon color="#ef4444">
                                            <Delete />
                                        </el-icon>
                                        <span style="color: #ef4444">删除</span>
                                    </el-dropdown-item>
                                </el-dropdown-menu>
                            </template>
                        </el-dropdown>
                    </div>
                    <div class="asset-card-body">
                        <div class="asset-name">{{ asset.name }}</div>
                        <div class="asset-balance">¥{{ formatMoney(asset.balance) }}</div>
                    </div>
                    <div class="asset-card-footer">
                        <span class="asset-date">创建于 {{ new Date(asset.createTime).toLocaleDateString() }}</span>
                    </div>
                </div>
            </el-col>
        </el-row>

        <!-- 新增/编辑对话框 -->
        <el-dialog v-model="dialogVisible" :title="dialogType === 'add' ? '新增账户' : '编辑账户'" width="400px">
            <el-form :model="form" label-width="80px">
                <el-form-item label="账户名称" required>
                    <el-input v-model="form.name" placeholder="如：银行卡、支付宝" />
                </el-form-item>
                <el-form-item label="初始余额" v-if="dialogType === 'add'">
                    <el-input-number v-model="form.balance" :min="0" :precision="2" style="width: 100%" />
                </el-form-item>
            </el-form>
            <template #footer>
                <el-button @click="dialogVisible = false">取消</el-button>
                <el-button type="primary" @click="saveAsset">确定</el-button>
            </template>
        </el-dialog>
    </div>
</template>

<style scoped>
.assets-page {
    min-height: 100%;
}

.action-bar {
    margin-bottom: 24px;
}

.asset-card {
    background: #fff;
    border-radius: 16px;
    overflow: hidden;
    box-shadow: 0 2px 12px rgba(0, 0, 0, 0.08);
    margin-bottom: 24px;
    transition: all 0.3s ease;
}

.asset-card:hover {
    transform: translateY(-6px);
    box-shadow: 0 12px 32px rgba(90, 74, 63, 0.15);
}

.asset-card-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 20px 20px 0;
}

.asset-icon {
    width: 56px;
    height: 56px;
    display: flex;
    align-items: center;
    justify-content: center;
    background: rgba(193, 124, 74, 0.1);
    color: var(--accent-gold);
    border-radius: 14px;
}

.asset-card-body {
    padding: 20px;
}

.asset-name {
    font-size: 16px;
    font-weight: 500;
    color: var(--text-body);
    margin-bottom: 8px;
}

.asset-balance {
    font-size: 28px;
    font-weight: 700;
    color: var(--text-main);
    font-variant-numeric: tabular-nums;
}

.asset-card-footer {
    padding: 12px 20px;
    background: #fdfbf7;
    border-top: 1px solid #f0eae6;
}

.asset-date {
    font-size: 12px;
    color: var(--text-muted);
}

.empty-state {
    background: #fff;
    border-radius: 16px;
    padding: 80px 40px;
}
</style>
