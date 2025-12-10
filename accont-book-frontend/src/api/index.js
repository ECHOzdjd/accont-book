import axios from 'axios'
import { ElMessage } from 'element-plus'

// 创建axios实例
const api = axios.create({
  baseURL: '/api',
  timeout: 10000,
})

// 响应拦截器
api.interceptors.response.use(
  (response) => {
    const res = response.data
    if (res.code !== 200) {
      ElMessage.error(res.msg || '请求失败')
      return Promise.reject(new Error(res.msg || '请求失败'))
    }
    return res
  },
  (error) => {
    ElMessage.error(error.message || '网络错误')
    return Promise.reject(error)
  }
)

// 默认用户ID（暂无登录功能）
const DEFAULT_USER_ID = 1

// ============ 资产 API ============

/**
 * 获取用户资产列表
 */
export const getAssets = (userId = DEFAULT_USER_ID) => {
  return api.get(`/assets/user/${userId}`)
}

/**
 * 获取资产详情
 */
export const getAssetById = (id) => {
  return api.get(`/assets/${id}`)
}

/**
 * 创建资产
 */
export const createAsset = (data) => {
  return api.post('/assets', {
    userId: DEFAULT_USER_ID,
    ...data,
  })
}

/**
 * 更新资产名称
 */
export const updateAsset = (id, name) => {
  return api.put(`/assets/${id}`, { name })
}

/**
 * 删除资产
 */
export const deleteAsset = (id) => {
  return api.delete(`/assets/${id}`)
}

// ============ 流水 API ============

/**
 * 获取用户流水列表
 */
export const getTransactions = (userId = DEFAULT_USER_ID) => {
  return api.get(`/transactions/user/${userId}`)
}

/**
 * 获取资产流水列表
 */
export const getTransactionsByAsset = (assetId) => {
  return api.get(`/transactions/asset/${assetId}`)
}

/**
 * 新增记账
 */
export const addTransaction = (data) => {
  return api.post('/transactions', {
    userId: DEFAULT_USER_ID,
    ...data,
  })
}

/**
 * 删除流水
 */
export const deleteTransaction = (id) => {
  return api.delete(`/transactions/${id}`)
}

// ============ 统计 API ============

/**
 * 获取当月概览
 */
export const getCurrentMonthSummary = (userId = DEFAULT_USER_ID) => {
  return api.get(`/stats/summary/${userId}`)
}

/**
 * 获取月度统计（最近N个月）
 */
export const getMonthlyStatistics = (userId = DEFAULT_USER_ID, months = 6) => {
  return api.get(`/stats/monthly/${userId}?months=${months}`)
}

/**
 * 获取分类统计
 */
export const getCategoryStatistics = (userId = DEFAULT_USER_ID, month, type) => {
  let url = `/stats/category/${userId}?`
  if (month) url += `month=${month}&`
  if (type) url += `type=${type}`
  return api.get(url)
}

// ============ 用户 API ============

/**
 * 用户登录
 */
export const login = (username, password) => {
  return api.post('/users/login', { username, password })
}

/**
 * 用户注册
 */
export const register = (username, password) => {
  return api.post('/users/register', { username, password })
}

/**
 * 获取用户信息
 */
export const getUserById = (id) => {
  return api.get(`/users/${id}`)
}

export default api
