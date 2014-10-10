package com.abstratt.mdd.target.mean.tests

import com.abstratt.kirra.mdd.core.KirraMDDCore
import com.abstratt.mdd.core.IRepository
import com.abstratt.mdd.core.target.TargetCore
import com.abstratt.mdd.core.tests.harness.AbstractRepositoryBuildingTests
import com.abstratt.mdd.core.tests.harness.AssertHelper
import com.abstratt.mdd.target.mean.mongoose.DomainModelGenerator
import java.io.IOException
import java.util.Properties
import junit.framework.Test
import junit.framework.TestSuite
import org.eclipse.core.runtime.CoreException
import org.eclipse.uml2.uml.UMLPackage

class MongooseDomainModelTests extends AbstractRepositoryBuildingTests {

    DomainModelGenerator generator = new DomainModelGenerator

    def static Test suite() {
        return new TestSuite(MongooseDomainModelTests)
    }

    new(String name) {
        super(name)
    }

    def testSimpleModel() throws CoreException, IOException {
        var source = '''
        model simple;
          class Class1
              attribute attr1 : String;
              attribute attr2 : Integer;
              attribute attr3 : Date;            
          end;
        end.
        '''
        parseAndCheck(source)

        val mapped = map("simple::Class1")
        
        AssertHelper.assertStringsEqual(
        '''
        var class1Schema = new Schema({ 
            attr1: String, 
            attr2: Number,
            attr3: Date
        }); 
        var Class1 = mongoose.model('Class1', class1Schema);      
        '''
        , mapped)
    }
    
    def testAction() throws CoreException, IOException {
        val source = '''
        model simple;
        class Class1
            attribute attr1 : Integer;
            operation incAttr1(value : Integer);
            begin
                self.attr1 := self.attr1 + value;
            end;            
        end;
        end.
        '''
        parseAndCheck(source)

        val mapped = map("simple::Class1")
        
        AssertHelper.assertStringsEqual(
        '''
        var class1Schema = new Schema({ 
            attr1: Number 
        }); 
        class1Schema.methods.incAttr1 = function (value) {
            this.attr1 = this.attr1 + value; 
        };
        var Class1 = mongoose.model('Class1', class1Schema);      
        ''', mapped)
    }
    
    def testExtent() throws CoreException, IOException {
        val source = '''
        model crm;
        class Customer
            attribute name : String;
            static query allCustomers() : Customer[*];
            begin
                return Customer extent;
            end;            
        end;
        end.
        '''
        parseAndCheck(source)

        val mapped = generator.generateQueryOperation(getOperation("crm::Customer::allCustomers")).toString()
        
        AssertHelper.assertStringsEqual(
        '''
        customerSchema.statics.allCustomers = function () {
            return this.model('Customer').find().exec(); 
        };
        ''', mapped.toString)
    }
    
    def testSelectByBooleanProperty() throws CoreException, IOException {
        val source = '''
        model crm;
        class Customer
            attribute name : String;
            attribute mvp : Boolean;
            static query mvpCustomers() : Customer[*];
            begin
                return Customer extent.select((c : Customer) : Boolean { c.mvp = true});
            end;            
        end;
        end.
        '''
        parseAndCheck(source)

        val mapped = generator.generateQueryOperation(getOperation("crm::Customer::mvpCustomers")).toString()
        
        AssertHelper.assertStringsEqual(
        '''
        customerSchema.statics.mvpCustomers = function () {
            return this.model('Customer').find().where('mvp').equals(true).exec(); 
        };
        ''', mapped)
    }
    

    def testSelectByPropertyGreaterThan() throws CoreException, IOException {
        val source = '''
        model banking;
        class Account
            attribute number : String;
            attribute balance : Double;
            static query bestAccounts(threshold : Double) : Account[*];
            begin
                return Account extent.select((a : Account) : Boolean { a.balance > threshold });
            end;            
        end;
        end.
        '''
        parseAndCheck(source)

        val mapped = generator.generateQueryOperation(getOperation("banking::Account::bestAccounts")).toString()
        
        AssertHelper.assertStringsEqual(
        '''
        accountSchema.statics.bestAccounts = function (threshold) {
            return this.model('Account').find().where('balance').gt(threshold).exec(); 
        };
        ''', mapped)
    }

    def testSum() throws CoreException, IOException {
        val source = '''
        model banking;
        class Account
            attribute number : String;
            attribute balance : Double;
            static query totalBalance() : Double;
            begin
                return Account extent.sum((a : Account) : Double { a.balance  });
            end;            
        end;
        end.
        '''
        parseAndCheck(source)

        val mapped = generator.generateQueryOperation(getOperation("banking::Account::totalBalance")).toString()
        
        AssertHelper.assertStringsEqual(
        '''
        accountSchema.statics.totalBalance = function () {
            return this.model('Account').aggregate()
                .group({ _id: null, result: { $sum: '$balance' } })
                .select('-id result')
                .exec();
        };
        ''', mapped)
    }
    
    override Properties createDefaultSettings() {
        val defaultSettings = super.createDefaultSettings()
        // so the kirra profile is available as a system package (no need to
        // load)
        defaultSettings.setProperty("mdd.enableKirra", Boolean.TRUE.toString())
        // so kirra stereotypes are automatically applied
        defaultSettings.setProperty(IRepository.WEAVER, KirraMDDCore.WEAVER)
        // so classes extend Object by default (or else weaver ignores them)
        defaultSettings.setProperty(IRepository.EXTEND_BASE_OBJECT, Boolean.TRUE.toString())
        return defaultSettings
    }
    
    private def map(String className) {
        val platform = TargetCore.getPlatform(getRepository().getProperties(), "mean")
        val mapper = platform.getMapper(null)
        val class1 = getRepository().findNamedElement(className, UMLPackage.Literals.CLASS, null)
        return mapper.map(class1).toString()
    }
}
