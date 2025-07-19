import { NextRequest, NextResponse } from 'next/server'
import { setUserRole, adminAuth } from '@/lib/firebase-admin'
import { config } from '@/lib/config'

// 初回管理者設定用のエンドポイント
// 管理者が一人もいない場合のみ、自分自身を管理者に設定できる
export async function POST(request: NextRequest) {
  try {
    // 認証トークンを検証
    const authHeader = request.headers.get('authorization')
    if (!authHeader?.startsWith('Bearer ')) {
      return NextResponse.json(
        { success: false, message: 'No authorization token provided' },
        { status: 401 }
      )
    }

    const token = authHeader.split('Bearer ')[1]
    
    // トークンを検証して現在のユーザー情報を取得
    const decodedToken = await adminAuth.verifyIdToken(token)
    const currentUserId = decodedToken.uid
    const currentUserEmail = decodedToken.email

    // 環境別の設定
    const { isDevelopment, isProduction } = config.env
    const initialAdminEmail = config.auth.initialAdminEmail

    // 本番環境では INITIAL_ADMIN_EMAIL が必須
    if (isProduction && !initialAdminEmail) {
      return NextResponse.json(
        { success: false, message: 'Initial admin email not configured for production environment' },
        { status: 500 }
      )
    }

    // すでに管理者が存在するかチェック
    const allUsers = await adminAuth.listUsers()
    const adminExists = allUsers.users.some(user => 
      user.customClaims?.role === 'admin'
    )

    if (adminExists) {
      return NextResponse.json(
        { 
          success: false, 
          message: 'Admin already exists. Please contact existing admin to grant permissions.' 
        },
        { status: 403 }
      )
    }

    // 本番環境では指定されたメールアドレスのみ管理者になれる
    if (isProduction && currentUserEmail !== initialAdminEmail) {
      return NextResponse.json(
        { 
          success: false, 
          message: 'You are not authorized to become the initial admin' 
        },
        { status: 403 }
      )
    }

    // 管理者が存在しない場合、現在のユーザーを管理者に設定
    await setUserRole(currentUserId, 'admin')
    
    return NextResponse.json({ 
      success: true, 
      message: `Successfully set ${currentUserEmail} as admin`,
      requiresTokenRefresh: true
    })
  } catch (error) {
    console.error('Error initializing admin:', error)
    return NextResponse.json(
      { success: false, message: 'Internal server error' },
      { status: 500 }
    )
  }
}