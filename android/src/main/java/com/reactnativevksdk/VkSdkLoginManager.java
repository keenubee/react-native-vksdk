package com.reactnativevksdk;

import android.app.Activity;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.widget.Toast;

import com.facebook.react.bridge.ActivityEventListener;
import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.Callback;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.WritableArray;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.bridge.WritableNativeArray;
import com.facebook.react.bridge.WritableNativeMap;
import com.vk.sdk.VKAccessToken;
import com.vk.sdk.VKCallback;
import com.vk.sdk.VKSdk;
import com.vk.sdk.api.VKApi;
import com.vk.sdk.api.VKApiConst;
import com.vk.sdk.api.VKError;
import com.vk.sdk.api.VKParameters;
import com.vk.sdk.api.VKRequest;
import com.vk.sdk.api.VKResponse;
import com.vk.sdk.api.model.VKScopes;
import com.vk.sdk.api.photo.VKImageParameters;
import com.vk.sdk.api.photo.VKUploadImage;
import com.vk.sdk.dialogs.VKShareDialogBuilder;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.IOException;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.Iterator;

public class VkSdkLoginManager extends ReactContextBaseJavaModule implements ActivityEventListener {

	private static final String TAG = "VK_SDK_REACT_NATIVE";

	Callback loginCallback;

	public VkSdkLoginManager(ReactApplicationContext reactContext) {
		super(reactContext);
		reactContext.addActivityEventListener(this);
	}

	@Override
	public String getName() {
		return "VkSdkLoginManager";
	}

	@ReactMethod
	public void authorize(final Callback callback) {
		this.loginCallback = callback;
		if(!VKSdk.isLoggedIn())
			VKSdk.login(getCurrentActivity(), VKScopes.FRIENDS, VKScopes.EMAIL, VKScopes.GROUPS, VKScopes.WALL, VKScopes.PHOTOS);
		else {
			VKSdk.wakeUpSession(getReactApplicationContext(), new VKCallback<VKSdk.LoginState>() {
				@Override
				public void onResult(VKSdk.LoginState res) {
					if (loginCallback != null) {
						loginCallback.invoke(null, buildResponseData());
						loginCallback = null;
					}
				}

				@Override
				public void onError(VKError error) {
					if (loginCallback != null) {
						loginCallback.invoke(formatErrorMessage(error), null);
						loginCallback = null;
					}
				}
			});
		}
	}

	@ReactMethod
	public void logout() {
		VKSdk.logout();
	}

	@ReactMethod
	public void showShareDialogWithSharingContent(ReadableMap shareContent, final Callback shareCallback) {
		VKShareDialogBuilder builder = new VKShareDialogBuilder()
				.setAttachmentLink(shareContent.getString("linkTitle"), shareContent.getString("linkURL"));

		Bitmap bitmap = getBitmapFromUrl(shareContent.getString("imageURL"));
		if (bitmap != null) {
			builder.setAttachmentImages(new VKUploadImage[]{new VKUploadImage(bitmap, VKImageParameters.jpgImage(1.0f))});
		} else {
			Toast.makeText(getReactApplicationContext(), "Невозможно загрузить изображение", Toast.LENGTH_SHORT).show();
		}

		builder.setShareDialogListener(new VKShareDialogBuilder.VKShareDialogListener() {
			@Override
			public void onVkShareComplete(int postId) {
				shareCallback.invoke(null, "done");
			}

			@Override
			public void onVkShareCancel() {
				shareCallback.invoke("cancelled", null);
			}

			@Override
			public void onVkShareError(VKError error) {
				shareCallback.invoke(formatErrorMessage(error), null);
			}
		});

		builder.show(getCurrentActivity().getFragmentManager(), "VK_SHARE_DIALOG");

	}

	@ReactMethod
	public void getFriendsListWithFields(String userFields, final Callback callback) {
		VKRequest getFriendsRequest = VKApi.friends().get(VKParameters.from(VKApiConst.FIELDS, userFields));
		getFriendsRequest.executeWithListener(new VKRequest.VKRequestListener() {
			@Override
			public void onComplete(VKResponse response) {
				super.onComplete(response);

//				---------Json users array test--------
//				JSONObject resultJSON = new JSONObject();
//				JSONArray array = new JSONArray();
//
//				try {
//					for (int i = 0; i < 5; i++) {
//						JSONObject user = new JSONObject();
//						user.put("id",i);
//						user.put("first_name","Jane");
//						user.put("last_name","Doe");
//						user.put("bdate","07.01.1997");
//						user.put("photo_200_orig","https://pp.vk.me/c630225/v630225480/3bd1f/no0WJCR6b5U.jpg");
//						array.put(user);
//					}
//					resultJSON.put("items", array);
//				} catch (JSONException e) {
//					e.printStackTrace();
//				}

				try {
					WritableMap result = jsonToWritableMap(response.json.getJSONObject("response"));
					callback.invoke(null, result);
				} catch (JSONException e) {
					e.printStackTrace();
					callback.invoke("Ошибка получения списка друзей", null);
				}
			}

			@Override
			public void onError(VKError error) {
				super.onError(error);
			}
		});

	}

	private String formatErrorMessage(VKError error) {
		String errorMessage = error.errorMessage;

		if (errorMessage == null)
			errorMessage = "Unknown error";

		return errorMessage;
	}

	private WritableMap buildResponseData() {
		VKAccessToken token = VKAccessToken.currentToken();

		WritableMap response = Arguments.createMap();
		WritableMap credentials = Arguments.createMap();

		credentials.putString("token", token.accessToken);
		credentials.putString("userId", token.userId);
		response.putMap("credentials", credentials);
		return response;
	}

	private Bitmap getBitmapFromUrl(String Url) {
		try {
			URL url = new URL(Url);
			HttpURLConnection connection = (HttpURLConnection) url.openConnection();
			connection.setDoInput(true);
			connection.connect();
			InputStream input = connection.getInputStream();
			Bitmap bitmap = BitmapFactory.decodeStream(input);
			return bitmap;
		} catch (IOException ex) {
			ex.printStackTrace();
			return null;
		}
	}

	public static WritableMap jsonToWritableMap(JSONObject jsonObject) {
		WritableMap writableMap = new WritableNativeMap();

		if (jsonObject == null) {
			return null;
		}


		Iterator<String> iterator = jsonObject.keys();
		if (!iterator.hasNext()) {
			return null;
		}

		while (iterator.hasNext()) {
			String key = iterator.next();

			try {
				Object value = jsonObject.get(key);

				if (value == null) {
					writableMap.putNull(key);
				} else if (value instanceof Boolean) {
					writableMap.putBoolean(key, (Boolean) value);
				} else if (value instanceof Integer) {
					writableMap.putInt(key, (Integer) value);
				} else if (value instanceof Double) {
					writableMap.putDouble(key, (Double) value);
				} else if (value instanceof String) {
					writableMap.putString(key, (String) value);
				} else if (value instanceof JSONObject) {
					writableMap.putMap(key, jsonToWritableMap((JSONObject) value));
				} else if (value instanceof JSONArray) {
					writableMap.putArray(key, jsonArrayToWritableArray((JSONArray) value));
				}
			} catch (JSONException ex) {
				// Do nothing and fail silently
			}
		}

		return writableMap;
	}

	public static WritableArray jsonArrayToWritableArray(JSONArray jsonArray) {
		WritableArray writableArray = new WritableNativeArray();

		if (jsonArray == null) {
			return null;
		}

		if (jsonArray.length() <= 0) {
			return null;
		}

		for (int i = 0; i < jsonArray.length(); i++) {
			try {
				Object value = jsonArray.get(i);
				if (value == null) {
					writableArray.pushNull();
				} else if (value instanceof Boolean) {
					writableArray.pushBoolean((Boolean) value);
				} else if (value instanceof Integer) {
					writableArray.pushInt((Integer) value);
				} else if (value instanceof Double) {
					writableArray.pushDouble((Double) value);
				} else if (value instanceof String) {
					writableArray.pushString((String) value);
				} else if (value instanceof JSONObject) {
					writableArray.pushMap(jsonToWritableMap((JSONObject) value));
				} else if (value instanceof JSONArray) {
					writableArray.pushArray(jsonArrayToWritableArray((JSONArray) value));
				}
			} catch (JSONException e) {
				// Do nothing and fail silently
			}
		}

		return writableArray;
	}

	@Override
	public void onActivityResult(Activity activity, int requestCode, int resultCode, Intent data) {
		if (loginCallback != null) {
			VKSdk.onActivityResult(requestCode, resultCode, data, new VKCallback<VKAccessToken>() {
				@Override
				public void onResult(VKAccessToken res) {
					// User passed Authorization
					loginCallback.invoke(null, buildResponseData());
					loginCallback = null;
				}

				@Override
				public void onError(VKError error) {
					loginCallback.invoke(formatErrorMessage(error), null);
					loginCallback = null;
				}
			});
		}
	}

	@Override
	public void onNewIntent(Intent intent) {

	}
}
