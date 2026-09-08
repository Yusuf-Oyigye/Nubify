import 'chat_sevice.dart';
import 'group_chat_service.dart';

//===============================
// CHAT SHARE SERVICE
//===============================

class ChatShareService {
  final ChatService
  _chatService =
  ChatService();

  final GroupChatService
  _groupChatService =
  GroupChatService();

  //===============================
  // POST TO USER
  //===============================

  Future<void> sendPostToUser({
    required String receiverId,
    required String postId,
    required String postOwnerId,
    required String postUsername,
    required String postFullName,
    required String postCaption,
    required String postPreviewUrl,
  }) async {
    await _chatService
        .sendPostMessage(
      receiverId:
      receiverId,

      postId:
      postId,

      postOwnerId:
      postOwnerId,

      postUsername:
      postUsername,

      postFullName:
      postFullName,

      postCaption:
      postCaption,

      postPreviewUrl:
      postPreviewUrl,
    );
  }

  //===============================
  // POST TO GROUP
  //===============================

  Future<void> sendPostToGroup({
    required String groupId,
    required String postId,
    required String postOwnerId,
    required String postUsername,
    required String postFullName,
    required String postCaption,
    required String postPreviewUrl,
  }) async {
    await _groupChatService
        .sendPostMessage(
      groupId:
      groupId,

      postId:
      postId,

      postOwnerId:
      postOwnerId,

      postUsername:
      postUsername,

      postFullName:
      postFullName,

      postCaption:
      postCaption,

      postPreviewUrl:
      postPreviewUrl,
    );
  }

  //===============================
  // STORY TO USER
  //===============================

  Future<void> sendStoryToUser({
    required String receiverId,
    required String storyId,
    required String storyOwnerId,
    required String storyUsername,
    required String storyPreviewUrl,
    required String storyType,
  }) async {
    await _chatService
        .sendStoryMessage(
      receiverId:
      receiverId,

      storyId:
      storyId,

      storyOwnerId:
      storyOwnerId,

      storyUsername:
      storyUsername,

      storyPreviewUrl:
      storyPreviewUrl,

      storyType:
      storyType,
    );
  }

  //===============================
  // STORY TO GROUP
  //===============================

  Future<void> sendStoryToGroup({
    required String groupId,
    required String storyId,
    required String storyOwnerId,
    required String storyUsername,
    required String storyPreviewUrl,
    required String storyType,
  }) async {
    await _groupChatService
        .sendStoryMessage(
      groupId:
      groupId,

      storyId:
      storyId,

      storyOwnerId:
      storyOwnerId,

      storyUsername:
      storyUsername,

      storyPreviewUrl:
      storyPreviewUrl,

      storyType:
      storyType,
    );
  }

  //===============================
  // PRODUCT TO USER
  //===============================

  Future<void>
  sendProductToUser({
    required String receiverId,
    required String productId,
    required String productSellerId,
    required String productName,
    required String productImageUrl,
    required String productPrice,
  }) async {
    await _chatService
        .sendProductMessage(
      receiverId:
      receiverId,

      productId:
      productId,

      productSellerId:
      productSellerId,

      productName:
      productName,

      productImageUrl:
      productImageUrl,

      productPrice:
      productPrice,
    );
  }

  //===============================
  // PRODUCT TO GROUP
  //===============================

  Future<void>
  sendProductToGroup({
    required String groupId,
    required String productId,
    required String productSellerId,
    required String productName,
    required String productImageUrl,
    required String productPrice,
  }) async {
    await _groupChatService
        .sendProductMessage(
      groupId:
      groupId,

      productId:
      productId,

      productSellerId:
      productSellerId,

      productName:
      productName,

      productImageUrl:
      productImageUrl,

      productPrice:
      productPrice,
    );
  }
}