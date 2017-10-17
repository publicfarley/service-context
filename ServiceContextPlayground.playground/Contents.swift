//: Playground - noun: a place where people can play
import Foundation

// For convenience
extension String: Error {}

// Login :: UserCredentials -> Session
// Session -> Collection of functions with the session "baked in".

/* We are going to an opinionated Result. Even though conceptually its an Either type, we are going to follow the Rust model of Result<T,Error>. That is the data comes first (i.e. on the *left*.
 */
enum Result<SuccessType,Error> {
    
    case success(SuccessType)
    case error(Error)
    
    func map<T>(_ transform: (SuccessType) -> T) -> Result<T,Error> {
        switch self {
        case .success(let successValue):
            return Result<T,Error>.success(transform(successValue))
        case .error(let errorValue):
            return Result<T,Error>.error(errorValue)
        }
    }
    
    // (>>=) :: (Monad m) => m a -> (a -> m b) -> m b
    func bind<T>(_ transform: (SuccessType) -> Result<T,Error>) -> Result<T,Error> {
        
        switch self {
        case .success(let successValue):
            return transform(successValue)
            
        case .error(let errorValue):
            return Result<T,Error>.error(errorValue)
        }
    }
    
    func successValue() -> SuccessType? {
        switch self {
        case .success(let successValue):
            return successValue
            
        case .error:
            return nil
        }
    }
}

// Error utility functions
extension Result {
    
    func mapError<T>(_ transform: (Error) -> T) -> Result<SuccessType,T> {
        switch self {
        case .success(let successValue):
            return Result<SuccessType,T>.success(successValue)
            
        case .error(let errorValue):
            return Result<SuccessType,T>.error(transform(errorValue))
        }
    }
    
    // (>>=) :: (Monad m) => m a -> (a -> m b) -> m b
    func bindError<T>(_ transform: (Error) -> Result<SuccessType,T>) -> Result<SuccessType,T> {
        
        switch self {
        case .success(let successValue):
            return Result<SuccessType,T>.success(successValue)
            
        case .error(let errorValue):
            return transform(errorValue)
        }
    }
    
    func errorValue() -> Error? {
        switch self {
        case .success:
            return nil
            
        case .error(let value):
            return value
        }
    }
}

typealias Amount = NSNumber

struct UserCredentials {
    let userID: String
    let password: String
}

struct Account {
    let accountID: String
    let balance: Amount
}

extension Account: CustomStringConvertible {
    var description: String {
        return "ID: \(accountID), balance: \(balance)"
    }
}


protocol RemoteServices {
    static func login(with userCredentials: UserCredentials) -> Result<RemoteServices,Error>
    
    func retrieveAccountList() -> Result<[Account],Error>
    func transferFunds(amount: Amount, from fromAccount: Account, to toAccount: Account) -> Result<ConfirmationNumber,Error>
}

typealias SessionID = String
typealias ConfirmationNumber = String

// TODO: Future development
//struct AccountListRetievalRequest: Codable {
//    let sessionID: SessionID
//}


struct RemoteServicesWithSessionContext: RemoteServices {
    
    let sessionID: SessionID

    static func login(with userCredentials: UserCredentials) -> Result<RemoteServices,Error> {
        return retrieveSessionID(for: userCredentials).map { sessionID in
            return RemoteServicesWithSessionContext(sessionID: sessionID)
        }
    }
    
    func transferFunds(amount: Amount, from fromAccount: Account, to toAccount: Account) -> Result<ConfirmationNumber, Error> {
        
        guard amount.doubleValue <= fromAccount.balance.doubleValue else {
            return Result.error("amount to withdraw: \(amount) is greater than the from account balance: \(fromAccount.balance)")
        }
        
        print("I'm sessionID: \(sessionID). transfered \(amount) from account:\(fromAccount.accountID) to account:\(toAccount.accountID). New balances fromAccount:\(fromAccount.balance.doubleValue - amount.doubleValue) toAccount:\(toAccount.balance.doubleValue + amount.doubleValue)")
        
        return Result.success(UUID().uuidString)
    }
    
    func retrieveAccountList() -> Result<[Account], Error> {
        let accountList = [Account(accountID: "1", balance: 50.00),
                           Account(accountID: "2", balance: 2730.00)]
        
        print("I'm sessionID: \(self.sessionID). Retrieved account list: \(accountList)")
        //return Result.error("Network down. Could not retrieve accounts")
        return Result.success(accountList)
    }
    
    private static func retrieveSessionID(for userCredentials: UserCredentials) -> Result<SessionID,Error> {
        return Result.success(UUID().uuidString)
    }
    
}

let myUserCredentials = UserCredentials(userID: "myUserID", password: "myPassword")

let remoteServices = RemoteServicesWithSessionContext.login(with: myUserCredentials)

func transferFundsUseCase(remoteServices: RemoteServices) {
    remoteServices.retrieveAccountList().bind({ accounts in
        remoteServices.transferFunds(amount: Amount(value: 50), from: accounts[0], to: accounts[1])
    })
    .map({ confirmationNumber in
        print("Successfully transfered funds. Confirmation number: \(confirmationNumber)")
    })
    .mapError({ error in
        print("Could not transfer funds. Got error: \(error)")
    })
}

func remoteServicesInvocationErrorHandler(for error: Error) {
    print("😟: \(error)")
}

remoteServices
    .map(transferFundsUseCase)
    .mapError(remoteServicesInvocationErrorHandler)



